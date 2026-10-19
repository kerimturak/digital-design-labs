# flow/mk/regress.mk -- 'make regress' (Lab V1): tests x seeds x configurations from the
# block's dv/regress.list, each run an ordinary 'make sim'; summary table and exit code.
# Block-independent: included by the block Makefile after common.mk. The work is done by
# flow/scripts/regress.sh (list format documented there and in flow/README.md).
#
#   make regress                              whole list, seeds 1..N (reproducible)
#   make regress REGRESS_CONFIGS=w32d5        only some configurations / tests
#   make regress REGRESS_TESTS=random,smoke
#   make regress REGRESS_SEED_BASE=$(date +%s)   nightly: fresh seeds, printed in the summary
#   make regress REGRESS_JOBS=8               runs of one configuration in parallel
#   make regress SIM=verilator COV=1          variables other than PARAMS/DEFINES/TEST/SEED
#                                             reach every run; PLUSARGS are appended
# Output: build/<ip>/regress_summary.txt, build/<ip>/regress/<config>/<test>_s<seed>.out,
# and the normal sim logs build/<ip>/<cfg>/sim/<test>_s<seed>.log.

ifndef _REGRESS_MK
_REGRESS_MK := 1

REGRESS_LIST        ?= dv/regress.list
REGRESS_SUMMARY     ?= $(REPO_ROOT)/build/$(IP)/regress_summary.txt
REGRESS_SEED_BASE   ?= 0
REGRESS_JOBS        ?= 1
REGRESS_CONFIGS     ?=
REGRESS_TESTS       ?=
REGRESS_COVER_CHECK ?= 1

.PHONY: regress
regress:
	@+MAKE='$(MAKE)' $(REPO_ROOT)/flow/scripts/regress.sh --ip $(IP) --ip-dir $(IP_DIR) \
	   --list $(call flow_abs,$(REGRESS_LIST)) --summary $(REGRESS_SUMMARY) \
	   --seed-base $(REGRESS_SEED_BASE) --jobs $(REGRESS_JOBS) \
	   --configs '$(REGRESS_CONFIGS)' --tests '$(REGRESS_TESTS)' \
	   --cover-check $(REGRESS_COVER_CHECK)

HELP_TARGETS += regress
HELP_regress := run $(REGRESS_LIST) (tests x seeds x configs); summary $(REGRESS_SUMMARY)
HELP_VARS    += REGRESS_LIST REGRESS_SEED_BASE REGRESS_JOBS REGRESS_CONFIGS REGRESS_TESTS

endif # _REGRESS_MK
