| case | result | community bundle rejected by dyld because |
|---|---|---|
| hardened host, same-team bundled plugin (text) | opened with text (bundle) | different Team IDs |
| hardened host, ad-hoc community bundle | opened with csv-proc (process) | different Team IDs |
| hardened host, process plugin (unsigned script) | opened with csv-proc (process) | different Team IDs |
| hardened host, quarantined process plugin script | opened with csv-proc (process) | different Team IDs |
| + disable-library-validation, ad-hoc community bundle | opened with csv (bundle) | none |
| + disable-library-validation, quarantined ad-hoc bundle | opened with csv (bundle) | none |
| + disable-library-validation, unsigned bundle | opened with csv-proc (process) | missing code signature |
