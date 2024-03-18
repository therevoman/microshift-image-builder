# microshift-image-builder
Microshift rpm-ostree with image builder


### Execution
#### Create initial repository
You will need to provide a PROJECT_NAME environment variable to the make process to filter your files.  
example: 
```
PROJECT_NAME=rhel9-microshift make create
```

# To update an existing repository run
You will need to provide a PROJECT_NAME environment variable to the make process to filter your files.  
example: 
```
PROJECT_NAME=rhel9-microshift make update
```
