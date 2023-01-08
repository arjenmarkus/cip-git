# CIP - Calculating in Parallel

The CIP tool (Calculating in Parallel) is meant to solve a
common enough problem: use the computer's resources as efficiently as
possible without too much work. More specifically, it is meant for
this situation:

* You need to run a bunch of calculations with the same program, say various water quality scenarios.
* Each calculation takes a fairly long while, a couple of hours perhaps.
* The computational program does not use the entire computer, that is, it does not exploit its multiple processors to speed up the calculation.
* You do not want to sit around and wait for the calculations to be run one by one.

You could write a small batch file or shell script that simply starts the
various calculations and let it run on. But that might clog up the
computer. And if you use the cluster, you see yourself forced to
use one node per calculation.

Well, enter CIP. It helps you manage the calculations by
starting them in the background, but not more than there are
processors around. When a calculation is finished, the next is started
until there are no more calculations left. Management of these
calculations is automatic, you just need to follow a few simple
conventions.

Thes documentation describes what these conventions are and how
CIP does its work. Hopefully it is a useful tool.


