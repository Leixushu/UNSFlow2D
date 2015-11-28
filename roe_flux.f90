! Roe flux function
subroutine roe_flux(ie,c1,c2)
use commons
use pri
use grid
implicit none
real(kind=dp) :: x1(2), x2(2), qcl(nvar), qcr(nvar), qvl(nvar), &
            qvr(nvar), resl(nvar), resr(nvar)

integer(kind=i4)  :: i,ie,c1,c2
real(kind=dp) :: rl, ul, vl, pl, al2, hl, rr, ur, vr, pr, ar2, hr, &
            ua, va, qa2, aa2, aa, ha, &
            ql2, qr2, rl12, rr12, rd, &
            unl, unr, una, vna, F_c(4), Fd(4), &
            m1, m2, a1, a2, a3, a4, l1, l2, l3, l4, &
            a1l1, a2l2, a3l3, a4l4, aact, aast, &
            du1, du2, du3, du4, flux, dl, dr, li(4), limit, &
            e1, e4, del
real(kind=dp), parameter :: ETOL=0.01d0
real(kind=dp):: nx,ny,area,con(nvar),cl,cr,dist,grad(nvar) 

nx = fc(ie)%sx
ny = fc(ie)%sy
area = dsqrt(nx*nx + ny*ny)
nx = nx/area
ny = ny/area

qcl(:)=0.d0
qcr(:)=0.d0


!     Left state
qcl(:)=cell(c1)%qp(:)
do i=1,ndim
dist=fc(ie)%cen(i)-cell(c1)%cen(i)
qcl(:)=qcl(:)+cell(c1)%grad(i,:)*dist
enddo

rl = qcl(1)
ul = qcl(2)
vl = qcl(3)
pl = qcl(4)

!     Right state
qcr(:)=cell(c2)%qp(:)
do i=1,ndim
dist=fc(ie)%cen(i)-cell(c2)%cen(i)
qcr(:)=qcr(:)+cell(c2)%grad(i,:)*dist
enddo

rr = qcr(1)
ur = qcr(2)
vr = qcr(3)
pr = qcr(4)


ql2= ul*ul + vl*vl
al2= GAMMA*pl/rl
hl = al2/GAMMA1 + 0.5d0*ql2

qr2= ur*ur + vr*vr
ar2= GAMMA*pr/rr
hr = ar2/GAMMA1 + 0.5d0*qr2

!     Rotated velocity
unl = ul*nx + vl*ny
unr = ur*nx + vr*ny

!     Centered flux
f_c(2) = rl*unl            + rr*unr
f_c(3) = pl*nx + rl*ul*unl + pr*nx + rr*ur*unr
f_c(4) = pl*ny + rl*vl*unl + pr*ny + rr*vr*unr
f_c(1) = rl*hl*unl         + rr*hr*unr

!     Roe average
rl12 = dsqrt(rl)
rr12 = dsqrt(rr)
rd   = 1.0d0/(rl12 + rr12)

ua   = (ul*rl12 + ur*rr12)*rd
va   = (vl*rl12 + vr*rr12)*rd
ha   = (hl*rl12 + hr*rr12)*rd
qa2  = ua**2 + va**2
aa2  = GAMMA1*(ha - 0.5d0*qa2)

!#ifdef DEBUG
if(aa2 .le. 0.0d0)then
   print*,'Sonic speed is negative'
   print*,'Left/right cell values'
   print*,qcl(1),qcl(2),qcl(3),qcl(4)
   print*,qcr(1),qcr(2),qcr(3),qcr(4)
   print*,'Left/right vertex values'
   print*,qvl(1),qvl(2),qvl(3),qvl(4)
   print*,qvr(1),qvr(2),qvr(3),qvr(4)
   print*
   print*,rl,ul,vl,pl
   print*,rr,ur,vr,pr
   print*,li
   stop
endif
!#endif
aa  = dsqrt(aa2)
una = ua*nx + va*ny
vna =-ua*ny + va*nx

!     Eigenvalues with entropy fix
e1 = dabs(una - aa)
l2 = dabs(una)
l3 = l2
e4 = dabs(una + aa)

del= ETOL*aa
if(e1 .lt. del)then
   l1 = 0.5d0*(del + e1**2/del)
else
   l1 = e1
endif

if(e4 .lt. del)then
   l4 = 0.5d0*(del + e4**2/del)
else
   l4 = e4
endif

!     Difference of conserved variables
du1 = rr           - rl
du2 = rr*ur        - rl*ul
du3 = rr*vr        - rl*vl
du4 = (rr*hr - pr) - (rl*hl - pl)

!     Amplitudes
m1 = (nx*du2 + ny*du3 - una*du1)/aa
m2 = GAMMA1*(du4 - ua*du2 - va*du3 + qa2*du1)/aa**2

a4 = 0.5d0*(m1 + m2)
a1 = 0.5d0*(m2 - m1)
a3 = du1 - a1 - a4
a2 = ( ny*du2 - nx*du3 + vna*du1 )/aa

!     Diffusive flux
a1l1  = a1*l1
a2l2  = a2*l2
a3l3  = a3*l3
a4l4  = a4*l4
aact  = aa*nx
aast  = aa*ny

Fd(2) = a1l1               +               a3l3           + a4l4
Fd(3) = a1l1*(ua - aact)   + a2l2*aa*ny  + a3l3*ua        + &
        a4l4*(ua + aact)
Fd(4) = a1l1*(va - aast)   - a2l2*aa*nx  + a3l3*va        + &
        a4l4*(va + aast)
Fd(1) = a1l1*(ha - una*aa) + a2l2*aa*vna + a3l3*0.5d0*qa2 + &
        a4l4*(ha + una*aa)

!     Total flux
do i=1,4
   flux    = 0.5d0*area*( f_c(i) - Fd(i) )
   cell(c1)%res(i)=cell(c1)%res(i)+flux
   cell(c2)%res(i)=cell(c2)%res(i)-flux
enddo

end
