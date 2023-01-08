! streeter_sim_table.f90 --
!     Run a Streeter-Phelps model and write the results to a CSV file
!
program streeter_sim_table
    implicit none

    integer :: count
    real :: t, bod, do, deltt, tmax, reaer, depth, decay, dosat, dbod, ddo
    real :: tin, do_meas, bod_meas, sum_errors

    t     =  0.0
    tmax  = 20.0 ! days
    deltt =  0.1

    depth = 10.0 ! m
 !! reaer =  2.5 ! 1/day/m

 !! decay  = 0.4 ! 1/day
    dosat  = 7.8 ! gO/m3

 !! bod    = 10.0
 !! do     =  8.0

    open( 11, file = 'streeter_sim.inp' )
    read( 11, * ) bod
    read( 11, * ) do
    read( 11, * ) decay
    read( 11, * ) reaer
    close( 11 )

    open( 20, file = 'streeter_sim_table.out' )
    write( 20, '(a)' ) 'Time OXY BOD'

    count = 0
    do while ( t < tmax )
        if ( mod(count,10) == 0 ) then
            write( 20, * ) t, do, bod
        endif

        dbod = -decay * bod
        ddo  = -decay * bod + reaer * (dosat - do ) / depth

        bod  = bod + deltt * dbod
        do   = do  + deltt * ddo

        count = count + 1
        t     = deltt * count
    enddo

    close( 20 )
end program streeter_sim_table
