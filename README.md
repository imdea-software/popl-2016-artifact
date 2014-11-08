
This project aims to develop principled monitoring algorithms for concurrent
data structures, e.g., locks, semaphores, atomic registers, stacks, queues.

List of tasks:

- [ ] Generate lots of benchmark log files for the SCAL implementations.
- [x] Implement a linearization monitor.
- [x] Implement saturation via SAT/SMT (?).
- [x] Implement obsolete operation removal
- [x] Implement incremental SMT checking
- [ ] Implement incremental saturation checking

List of things to demonstrate:

- [ ] Our monitor correctly identifies violations.
- [ ] Our monitor has low space overhead / we don't keep too many operations.
- [ ] Our monitor has low runtime overhead.

List of experiments?

TODO
