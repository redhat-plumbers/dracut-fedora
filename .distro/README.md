This is a source-git, starting with downstream PR [2], which was generated from this repository without any other manual work.
So the repository state should always be on par with dist-git (although inheritance can go both ways), and it must never diverge.

The plan is to have the changes process automated. That is, when PR gets merged here (or any new commits land), a new PR with changes is opened on pagure.

I've elaborated on a relation with upstream in the downstream PR [2]. There's no plan to diverge from upstream at all. Source-git actually helps getting feedback to upstream better (please see packit docs on source-git[1]).

**[1] https://packit.dev/source-git**

[2] https://src.fedoraproject.org/rpms/dracut/pull-request/54
