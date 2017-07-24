module extern_gr
 implicit none

 public :: get_grforce, update_grforce_leapfrog

 private

contains

!---------------------------------------------------------------
!+
!  Wrapper subroutine for computing the force due to spacetime curvature
!  (This may be useful in the future if there is something that indicates
!   whether a particle is gas or test particle.)
!+
!---------------------------------------------------------------
subroutine get_grforce(xyzi,veli,densi,ui,pi,fexti)
 real, intent(in)  :: xyzi(3),veli(3),densi,ui,pi
 real, intent(out) :: fexti(3)
 logical :: its_a_testparticle
 its_a_testparticle = .false.

 if (its_a_testparticle) then
    call get_sourceterms(xyzi,veli,fexti)
 else
    call forcegr(xyzi,veli,densi,ui,pi,fexti)
 endif

end subroutine get_grforce

!----------------------------------------------------------------
!+
!  Compute the source terms required on the right hand side of
!  the relativistic momentum equation. These are of the form:
!   T^\mu\nu dg_\mu\nu/dx^i
!+
!----------------------------------------------------------------
subroutine forcegr(x,v,dens,u,p,fterm)
 use metric_tools, only: get_metric, get_metric_derivs
 use utils_gr,     only: get_u0
 real,    intent(in)  :: x(3),v(3),dens,u,p
 real,    intent(out) :: fterm(3)
 real    :: gcov(0:3,0:3), gcon(0:3,0:3)
 real    :: sqrtg
 real    :: dgcovdx1(0:3,0:3), dgcovdx2(0:3,0:3), dgcovdx3(0:3,0:3)
 real    :: v4(0:3), term(0:3,0:3)
 real    :: enth, uzero
 integer :: i,j

 call get_metric(x,gcov,gcon,sqrtg)
 call get_metric_derivs(x,dgcovdx1, dgcovdx2, dgcovdx3)
 enth = 1. + u + p/dens

 ! lower-case 4-velocity
 v4(0) = 1.
 v4(1:3) = v(:)

 ! first component of the upper-case 4-velocity
 call get_u0(x,v,uzero)

 ! energy-momentum tensor times sqrtg on 2rho*
 do j=0,3
    do i=0,3
       term(i,j) = 0.5*(enth*uzero*v4(i)*v4(j) + P*gcon(i,j)/(dens*uzero))
    enddo
 enddo

 ! source term
 fterm(1) = 0.
 fterm(2) = 0.
 fterm(3) = 0.
 do j=0,3
    do i=0,3
       fterm(1) = fterm(1) + term(i,j)*dgcovdx1(i,j)
       fterm(2) = fterm(2) + term(i,j)*dgcovdx2(i,j)
       fterm(3) = fterm(3) + term(i,j)*dgcovdx3(i,j)
    enddo
 enddo

end subroutine forcegr

! Wrapper routine to call get_forcegr for a test particle
subroutine get_sourceterms(x,v,fterm)
 real, intent(in)  :: x(3),v(3)
 real, intent(out) :: fterm(3)
 real :: dens,u,p

 P = 0.
 u = 0.
 dens = 1. ! this value does not matter (will cancel in the momentum equation)
 call forcegr(x,v,dens,u,p,fterm)
end subroutine get_sourceterms

subroutine update_grforce_leapfrog(vhalfx,vhalfy,vhalfz,fxi,fyi,fzi,fexti,dt,xi,yi,zi,densi,ui,pi)
 use io,             only:fatal
 real, intent(in)    :: dt,xi,yi,zi
 real, intent(in)    :: vhalfx,vhalfy,vhalfz
 real, intent(inout) :: fxi,fyi,fzi
 real, intent(inout) :: fexti(3)
 real, intent(in)    :: densi,ui,pi
 real                :: fextv(3)
 real                :: v1x, v1y, v1z, v1xold, v1yold, v1zold, vhalf2, erri, dton2
 logical             :: converged
 integer             :: its, itsmax
 integer, parameter  :: maxitsext = 50 ! maximum number of iterations on external force
 real, parameter :: tolv = 1.e-2
 real, parameter :: tolv2 = tolv*tolv
 real,dimension(3) :: pos,vel

 itsmax = maxitsext
 its = 0
 converged = .false.
 dton2 = 0.5*dt

 v1x = vhalfx
 v1y = vhalfy
 v1z = vhalfz
 vhalf2 = vhalfx*vhalfx + vhalfy*vhalfy + vhalfz*vhalfz
 fextv = 0. ! to avoid compiler warning

 iterations : do while (its < itsmax .and. .not.converged)
    its = its + 1
    erri = 0.
    v1xold = v1x
    v1yold = v1y
    v1zold = v1z
    pos = (/xi,yi,zi/)
    vel = (/v1x,v1y,v1z/)
    call get_grforce(pos,vel,densi,ui,pi,fextv)
!    xi = pos(1)
!    yi = pos(2)
!    zi = pos(3)
    v1x = vel(1)
    v1y = vel(2)
    v1z = vel(3)

    v1x = vhalfx + dton2*(fxi + fextv(1))
    v1y = vhalfy + dton2*(fyi + fextv(2))
    v1z = vhalfz + dton2*(fzi + fextv(3))

    erri = (v1x - v1xold)**2 + (v1y - v1yold)**2 + (v1z - v1zold)**2
    erri = erri / vhalf2
    converged = (erri < tolv2)

 enddo iterations

 if (its >= maxitsext) call fatal('update_grforce_leapfrog','VELOCITY ITERATIONS ON EXTERNAL FORCE NOT CONVERGED!!')

 fexti(1) = fextv(1)
 fexti(2) = fextv(2)
 fexti(3) = fextv(3)

 fxi = fxi + fexti(1)
 fyi = fyi + fexti(2)
 fzi = fzi + fexti(3)

end subroutine update_grforce_leapfrog


! !-----------------------------------------------------------------------
! !+
! !  writes input options to the input file
! !+
! !-----------------------------------------------------------------------
! subroutine write_options_ltforce(iunit)
!  use infile_utils, only:write_inopt
!  use physcon, only:pi
!  integer, intent(in) :: iunit
!
!  blackhole_spin_angle = blackhole_spin_angle*(180.0/pi)
!  write(iunit,"(/,a)") '# options relating to Lense-Thirring precession'
!  call write_inopt(blackhole_spin,'blackhole_spin','spin of central black hole (-1 to 1)',iunit)
!  call write_inopt(blackhole_spin_angle, &
!                  'blackhole_spin_angle','black hole spin angle w.r.t. x-y plane (0 to 180)',iunit)
!  blackhole_spin_angle = blackhole_spin_angle*(pi/180.0)
!
! end subroutine write_options_ltforce

! !-----------------------------------------------------------------------
! !+
! !  reads input options from the input file
! !+
! !-----------------------------------------------------------------------
! subroutine read_options_ltforce(name,valstring,imatch,igotall,ierr)
!  use io,      only:fatal
!  use physcon, only:pi
!  character(len=*), intent(in)  :: name,valstring
!  logical,          intent(out) :: imatch,igotall
!  integer,          intent(out) :: ierr
!  integer, save :: ngot = 0
!  character(len=30), parameter :: label = 'read_options_ltforce'
!
!  imatch  = .true.
!  igotall = .false.
!
!  select case(trim(name))
!  case('blackhole_spin')
!     read(valstring,*,iostat=ierr) blackhole_spin
!     if (blackhole_spin > 1 .or. blackhole_spin < -1.) then
!        call fatal(label,'invalid spin parameter for black hole')
!     endif
!     ngot = ngot + 1
!  case('blackhole_spin_angle')
!     read(valstring,*,iostat=ierr) blackhole_spin_angle
!     if (blackhole_spin_angle > 180. .or. blackhole_spin_angle < 0.) then
!        call fatal(label,'invalid spin angle for black hole (should be between 0 and 180 degrees)')
!     else
!        blackhole_spin_angle = blackhole_spin_angle*(pi/180.0)
!        sin_spinangle = sin(blackhole_spin_angle)
!        cos_spinangle = cos(blackhole_spin_angle)
!     endif
!  case default
!     imatch = .false.
!  end select
!
!  igotall = (ngot >= 1)
!
! end subroutine read_options_ltforce

end module extern_gr
