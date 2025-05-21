# Wow such fromfile

## Install extension

```
gh ext install williammartin/gh-from-file
```

## Create file

```
cat <<EOF > myrepo.yaml
positional:
  - my-repo
private: true
description: "my from file repo"
EOF
```

## Create repo from file

```
gh from-file myrepo.yaml repo create
✓ Created repository williammartin/my-repo on github.com
  https://github.com/williammartin/my-repo
```
