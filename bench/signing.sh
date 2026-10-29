#!/bin/zsh
# Does a hardened-runtime host load plugins it did not sign? Run after building PreviewPPLean (Release).
# usage: bench/signing.sh "<codesigning identity>"   e.g. "Apple Development: Jane Doe (TEAMID)"
set -u
identity=${1:?pass a codesigning identity from: security find-identity -v -p codesigning}
root=${0:A:h:h}
products=$root/build/dd/Build/Products/Release
work=$root/build/sign-test
fixtures=$root/bench/fixtures
rm -rf $work && mkdir -p $work/community
cp -R $products/PreviewPPLean.app $work/Host.app
# The CSV plugin comes only from the community folder, signed ad hoc like a stranger's download.
rm -rf $work/Host.app/Contents/PlugIns/PPCSV.pppplugin
cp -R $products/PreviewPPLean.app/Contents/PlugIns/PPCSV.pppplugin $work/community/
codesign -f -s - $work/community/PPCSV.pppplugin 2>/dev/null
cp -R $root/ExternalPlugins/csv-proc.pppproc $work/community/
print '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>com.apple.security.cs.disable-library-validation</key><true/></dict></plist>' > $work/dlv.plist

sign_host() {  # $1: extra codesign args for the app
  for item in $work/Host.app/Contents/Frameworks/*.framework $work/Host.app/Contents/PlugIns/*.pppplugin; do
    codesign -f -o runtime -s "$identity" $item 2>/dev/null
  done
  codesign -f -o runtime -s "$identity" ${=1} $work/Host.app 2>/dev/null
}

attempt() {  # $1: label, $2: file, $3: config
  local out=$work/out.jsonl conf=$work/config
  rm -f $out; print -r -- "$3" > $conf
  local log=$(PPP_CONFIG=$conf PPP_PLUGINS_DIR=$work/community PPP_BENCH_OUT=$out \
    perl -e 'alarm shift; exec @ARGV' 20 $work/Host.app/Contents/MacOS/PreviewPPLean $fixtures/$2 2>&1 | grep -oE "different Team IDs|missing code signature" | head -1)
  local result=$( [[ -s $out ]] && python3 -c 'import json,sys; r=json.loads(open(sys.argv[1]).read().splitlines()[-1]); print(r.get("failure") or r.get("note") or "opened with " + r["plugin"] + " (" + r["runtime"] + ")")' $out || echo "no result (host crashed or hung)")
  print "| $1 | $result | ${log:-none} |"
}

print "| case | result | community bundle rejected by dyld because |"
print "|---|---|---|"
sign_host ""
attempt "hardened host, same-team bundled plugin (text)" small.txt ""
attempt "hardened host, ad-hoc community bundle" small.csv "open.csv = csv"
attempt "hardened host, process plugin (unsigned script)" small.csv "open.csv = csv-proc"
xattr -w com.apple.quarantine "0083;$(printf %x $(date +%s));Safari;" $work/community/csv-proc.pppproc/main.py
attempt "hardened host, quarantined process plugin script" small.csv "open.csv = csv-proc"
sign_host "--entitlements $work/dlv.plist"
attempt "+ disable-library-validation, ad-hoc community bundle" small.csv "open.csv = csv"
xattr -rw com.apple.quarantine "0083;$(printf %x $(date +%s));Safari;" $work/community/PPCSV.pppplugin
attempt "+ disable-library-validation, quarantined ad-hoc bundle" small.csv "open.csv = csv"
codesign --remove-signature $work/community/PPCSV.pppplugin/Contents/MacOS/PPCSV 2>/dev/null
xattr -rc $work/community/PPCSV.pppplugin
attempt "+ disable-library-validation, unsigned bundle" small.csv "open.csv = csv"
