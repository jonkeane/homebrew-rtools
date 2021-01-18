# jonkeane/rtools

R tooling formulae for the [Homebrew](https://brew.sh) package manager.

## How do I install a formula?

```sh
brew tap brewsci/base
brew install FORMULA
```

or

```sh
brew install brewsci/base/FORMULA
```

## Updating formulae

To update a formula, make a separate branch and PR. Github Actions will run tests on the branch. Once the PR is good to go, the `Publish and commit bottles` action (with the correct PR filled in) will take the bottles built during the tests, publish them to bintray, update the bottles section of the formula, and merge the PR into the main branch.

The action `Dispatch build bottle` will both build and upload the bottles and then merge the branch into the main branch. To use this action, supply the macos version (in the form of `macos-10.15`), name of one formula, issue/PR number, and if the build should be uploaded to bintray. 

## Troubleshooting

First read the [Troubleshooting Checklist](http://docs.brew.sh/Troubleshooting.html).

Use `brew gist-logs FORMULA` to create a [Gist](https://gist.github.com/) and post the link in your issue.

Search the [issues](https://github.com/brewsci/homebrew-base/issues?q=). See also Homebrew's [Common Issues](https://docs.brew.sh/Common-Issues.html) and [FAQ](https://docs.brew.sh/FAQ.html).

## Documentation

`brew help`, `man brew`, or check [Homebrew's documentation](https://docs.brew.sh).
