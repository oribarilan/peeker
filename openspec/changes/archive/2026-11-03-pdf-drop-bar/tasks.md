# Tasks

## 1. Bar

- [x] 1.1 Write failing tests: the thumbnails' collection view gets a `ThumbnailDropBar` as delegate that still answers PDFKit's own messages; a drop the delegate allows shows the bar in the proposed gap (above page 1 for index 0, below the last page past the end, between pages otherwise) and one it refuses hides it; accepting a drop and the session ending hide it; with no collection view nothing is installed. Then add `ThumbnailDropBar` and install it from `PageThumbnails`; verify the tests and the existing PDF tests pass

## 2. Docs and version

- [x] 2.1 Add an Unreleased line to CHANGELOG and bump `MARKETING_VERSION` to `0.5.1-dev`, committed after this change; verify `openspec validate --all --strict`

## 3. Screen tests

- [x] 3.1 In the pdf-pages flow, take a screenshot partway through the drag of page 3 to the top and check the accent bar is there (a strongly colored pixel above page 1's thumbnail). After the drop page 3 is selected there and its highlight is accent-colored too, so the bar going away is left to the unit tests; verify `bash -n`

## 4. Wrap-up

- [x] 4.1 Run `scripts/build.sh` and `scripts/build.sh test` twice; verify all tests pass with no warnings
- [x] 4.2 Run the pdf-pages and pdf-edit screen flows (with the maintainer's go); verify they pass and look at the mid-drag capture

## Workflow follow-up

- Archive with `/opsx:archive` once done.
