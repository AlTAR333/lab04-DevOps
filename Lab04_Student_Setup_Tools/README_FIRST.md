# LAB 04 - Read this before starting

This pack preserves the 12-page original student-authored “Builds and Five-Environment Promotion Pipeline” document and inserts a separately labeled instructor installation supplement after the cover.

**Important external dependency:** the actual source code and the five gate test scripts belong to the student authors and are referenced at https://github.com/devopsapproach/04-citybike-sdlc . This repository could NOT be fetched or verified while packaging. The application and scripts are therefore **not** claimed to be included in this pack.

1. Read `Lab04_SDLC_Docker_With_Installation_EN.pdf` and follow the installation appendix.
2. Run `bash Lab04_Student_Setup_Tools/preflight.sh` from the extracted pack.
3. Clone the external repository as instructed and run `bash /PATH/TO/Lab04_Student_Setup_Tools/verify_starter.sh .` from inside it.
4. Only after all required files are present, run `npm ci`, `npm run build`, and the HTTP baseline tests.
5. If the repository is unavailable, request a verified source ZIP directly from the two student authors before class; do not improvise replacements for their test scripts.

Do not share production secrets. Use a Bash shell (WSL2 Ubuntu on Windows).
