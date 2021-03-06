!WRF:MEDIATION_LAYER
!
SUBROUTINE init_modules
 USE module_bc
 USE module_configure
 USE module_driver_constants
 USE module_model_constants
 USE module_domain
 USE module_machine
 USE module_nesting
 USE module_timing
 USE module_tiles
 USE module_io_wrf
 USE module_io
#ifdef DM_PARALLEL
 USE module_ext_quilt
 USE module_dm
#endif
#ifdef INTIO
 USE module_ext_internal
#endif

! <DESCRIPTION>
! This routine USES the modules in WRF and then calls the init routines
! they provide to perform module specific initializations at the
! beginning of a run.  Note, this is only once per run, not once per
! domain; domain specific initializations should be handled elsewhere,
! such as in <a href=start_domain.html>start_domain</a>.
! 
! Certain framework specific module initializations in this file are
! dependent on order they are called. For example, since the quilt module
! relies on internal I/O, the init routine for internal I/O must be
! called first.  In the case of DM_PARALLEL compiles, the quilt module
! calls MPI_INIT as part of setting up and dividing communicators between
! compute and I/O server tasks.  Therefore, it must be called prior to
! module_dm, which will <em>also</em> try to call MPI_INIT if it sees
! that MPI has not be initialized yet (implementations of module_dm
! should in fact behave this way by first calling MPI_INITIALIZED before
! they try to call MPI_INIT).  If MPI is already initialized before the
! the quilting module is called, quilting will not work.
! 
! </DESCRIPTION>

 CALL init_module_bc
 CALL init_module_configure
 CALL init_module_driver_constants
 CALL init_module_model_constants
 CALL init_module_domain
 CALL init_module_machine

#ifdef INTIO
 CALL init_module_ext_internal  !! must be called before quilt
#endif
#ifdef DM_PARALLEL
 CALL init_module_ext_quilt    !! this *must* be called before init_module_dm
 CALL init_module_dm
#endif
 CALL init_module_nesting
 CALL init_module_timing
 CALL init_module_tiles
 CALL init_module_io_wrf
 CALL init_module_io

! core specific initializations -- add new cores here
#if (EM_CORE == 1)
 CALL init_modules_em
#endif
#if (NMM_CORE == 1)
 CALL init_modules_nmm
#endif
#if (COAMPS_CORE == 1)
 CALL init_modules_coamps
#endif
 
END SUBROUTINE init_modules

