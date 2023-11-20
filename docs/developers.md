# Developers

## Building the documentation

To build this documentation website locally, first create a new conda environment.
```
conda create -n docs-env python=3.10 pip ipython
conda activate docs-env
python -m pip install -r requirements-docs.txt
```

Then you can use [mkdocs](https://www.mkdocs.org/) to serve the website locally.
```
mkdocs serve
```
Click the link to open the local webpages in your browser.
You can interactively edit the documentation, and refresh your browser to see the updated content.

### Editing the docs

To make changes to the contents of the website documentation, edit the markdown files in the `docs/` directory.

If you add new pages to the documentation, remember to also add them to the navigation "nav" list in the `mkdocs.yml` configuration file.

### Deploying the documentation

The documentation website is automatically deployed by the `deploy-docs.yml` Github Actions workflow, whenever an update is pushed to the `main` branch of the repository.
