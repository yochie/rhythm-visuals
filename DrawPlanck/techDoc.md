TechDoc
=======

Infrastructure / methodes
=======
## Repo
oui, si possible on se connecte au meme repo et on te passe nos user
https://github.com/yochie/rhythm-visuals

## Users
- nom d'utilisateur github pour yoann: yochie
- nom d'utilisateur github pour fred: fkrebs
- nom d'utilisateur github pour nina:


je pense qu'on peut simplifier au max l'utilisation de git, et on evoluera si necessaire
- pas besoin de branche de dev a mon avis

## Process
### Steps
1. pull (no conflicts assuming clean working dir)
2. boss boss
3. commit -a (les fichiers de config sont ignorés à cause de "git update-index --assume-unchanged ...")
4. push 
5. if push fails because not up to date: pull, handle merge if not automatic, push again

### Collaboration methods
#### Shared repository model
In the shared repository model, collaborators are granted push access to a single shared repository and topic branches are created when changes need to be made. Pull requests are useful in this model as they initiate code review and general discussion about a set of changes before the changes are merged into the main development branch. This model is more prevalent with small teams and organizations collaborating on private projects.

Sources:
https://help.github.com/articles/about-collaborative-development-models/
http://scottchacon.com/2011/08/31/github-flow.html

#### Cactus
Ca vient de ce post : https://barro.github.io/2016/02/a-succesful-git-branching-model-considered-harmful/

Module
=======
## Documentation
- 1 README.md : section module avec liens vers les fichiers
- 1 module.md par module ,

syntaxe Markdown : https://en.wikipedia.org/wiki/Markdown
