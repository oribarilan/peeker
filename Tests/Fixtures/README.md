# Test fixtures

`aes256-form.pdf` and `aes256-form-no-printing.pdf` are the test form from `Tests/FormPDF.swift`, locked with AES-256 (`/V 5 /R 6`), which no Apple framework writes. Open password `open`, permissions password `perms`. Made with [qpdf](https://github.com/qpdf/qpdf) 12.4:

```sh
qpdf --encrypt --user-password=open --owner-password=perms --bits=256 -- form.pdf aes256-form.pdf
qpdf --encrypt --user-password=open --owner-password=perms --bits=256 --print=none -- form.pdf aes256-form-no-printing.pdf
```

`aes256-form-low-res-printing.pdf` allows only low-resolution printing, and `aes256-form-no-open-password.pdf` opens without a password but doesn't allow assembly; PDFKit reads both limits as none. `rc4-40-form-no-changes.pdf` is the form locked with 40-bit RC4 (`/R 2`), which doesn't allow changes or comments:

```sh
qpdf --encrypt --user-password=open --owner-password=perms --bits=256 --print=low -- form.pdf aes256-form-low-res-printing.pdf
qpdf --encrypt --user-password= --owner-password=perms --bits=256 --assemble=n -- form.pdf aes256-form-no-open-password.pdf
qpdf --allow-weak-crypto --encrypt --user-password=open --owner-password=perms --bits=40 --modify=n --annotate=n -- form.pdf rc4-40-form-no-changes.pdf
```
