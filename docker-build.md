docker run \
  -m=9g \
  --name=homebrew \
  -e HOMEBREW_NO_ANALYTICS=1 \
  -e HOMEBREW_NO_AUTO_UPDATE=1 \
  -e HOMEBREW_NO_INSTALL_CLEANUP=1 \
  -it homebrew/ubuntu16.04 /bin/bash


mkdir -p /home/linuxbrew/.linuxbrew/Homebrew/Library/Taps/jonkeane &&
git clone --branch rstudio-v1.3 https://github.com/jonkeane/homebrew-base.git /home/linuxbrew/.linuxbrew/Homebrew/Library/Taps/jonkeane/homebrew-base &&
brew install --verbose --build-from-source rstudio-server


# alternatively
docker cp ~/Dropbox/homebrew-base homebrew:/home/linuxbrew/.linuxbrew/Homebrew/Library/Taps/jonkeane/


commit with working macos tests:
https://github.com/jonkeane/homebrew-base/runs/722382095?check_suite_focus=true



# for linuxbrew
rm -Rf /home/linuxbrew/.linuxbrew/Homebrew/Library/Taps/homebrew               
docker cp ~/Desktop/linuxbrew-core homebrew:/home/linuxbrew/.linuxbrew/Homebrew/Library/Taps/homebrew/homebrew-core
