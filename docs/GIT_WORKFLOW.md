```markdown
# Git in the Microcosme project

> *The people writes its annals; the developer writes `git log`.*
> Two histories of the same world.

## Why Git saved this project

Before Git, this project lost pieces of itself three times — each time to the
same disease: restoring an old file by mistake. A lost procedure
(`SpawnWord`), a mangled one (`StepCreature`), a vanished branch
(`BID_ERE`). Each time: hours of diagnosis, chasing a bug that was not a bug
but a **missing block**.

Since the repository exists, the cure is one command:

```bash
git checkout abc1234 -- MicroSim.pas