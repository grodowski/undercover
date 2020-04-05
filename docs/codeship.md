Sample configuration to run `undercover` in Codeship CI. Edit these fields in **Project Settings**.

**Setup commands**

```
rvm use 2.5.3 --install
bundle install
gem install undercover
```

**Test pipeline**

```
bundle exec rspec --format documentation --color
# fetch origin/master to have a ref to compare against
git remote set-branches --add origin master
git fetch
undercover -c origin/master
```
