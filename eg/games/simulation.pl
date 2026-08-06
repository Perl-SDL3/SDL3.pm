use v5.36;
use Affix      qw[Int Float UInt8 Pointer sizeof];
use SDL3       qw[:all];
use List::Util qw(min max);

# Configuration & Constants
my $SCREEN_W = 1024;
my $SCREEN_H = 768;
my $MAP_SIZE = 12;

# SDL_RenderGeometry requires a buffer for vertices
my $quad_verts = Affix::calloc( 6, sizeof(SDL_Vertex) );
my $qv_addr    = Affix::address($quad_verts);
my $QV_STRIDE  = sizeof(SDL_Vertex);    # 32 bytes

# Pinned float views for fast direct writes into the vertex buffer
my ( @qv_px, @qv_py, @qv_r, @qv_g, @qv_b, @qv_a );
for my $i ( 0 .. 5 ) {
    my $base = $qv_addr + ( $i * $QV_STRIDE );
    $qv_px[$i] = Affix::cast( $base + 0,  Pointer [Float] );
    $qv_py[$i] = Affix::cast( $base + 4,  Pointer [Float] );
    $qv_r[$i]  = Affix::cast( $base + 8,  Pointer [Float] );
    $qv_g[$i]  = Affix::cast( $base + 12, Pointer [Float] );
    $qv_b[$i]  = Affix::cast( $base + 16, Pointer [Float] );
    $qv_a[$i]  = Affix::cast( $base + 20, Pointer [Float] );
}

# 3D Math & Camera System
# We need to manually project 3D coordinates (x,y,z) to 2D screen (x,y)
# using a perspective matrix.
my $camera = {
    x   =>  6.0,
    y   => -10.0,
    z   =>  10.0,                 # Camera position (Eye)
    yaw => 0.0, pitch => -0.8,    # Rotation angles
    fov => 1.5,                   # Field of view
};

sub project_3d {
    my ( $x, $y, $z ) = @_;

    # 1. Translate world to camera space
    my $cx = $x - $camera->{x};
    my $cy = $y - $camera->{y};
    my $cz = $z - $camera->{z};

    # 2. Rotate (Yaw - rotation around Z axis in this world up-vector context)
    # Actually, let's stick to standard 3D: Z is UP.
    # Camera rotations:
    my $cos_y = cos( -$camera->{yaw} );
    my $sin_y = sin( -$camera->{yaw} );
    my $rx    = $cx * $cos_y - $cy * $sin_y;
    my $ry    = $cx * $sin_y + $cy * $cos_y;
    my $rz    = $cz;

    # 3. Rotate (Pitch - rotation around X axis)
    my $cos_p = cos( -$camera->{pitch} );
    my $sin_p = sin( -$camera->{pitch} );
    my $ry2   = $ry * $cos_p - $rz * $sin_p;
    my $rz2   = $ry * $sin_p + $rz * $cos_p;

    # 4. Perspective Projection
    # If point is behind camera, return undef
    return if $ry2 <= 0.1;
    my $scale    = 600;                                              # Focal length / Zoom
    my $screen_x = ( $rx / $ry2 ) * $scale + ( $SCREEN_W / 2 );
    my $screen_y = -( $rz2 / $ry2 ) * $scale + ( $SCREEN_H / 2 );    # Invert Y for screen coords
    return ( $screen_x, $screen_y, $ry2 );                           # Return Depth ($ry2) for sorting
}

# Pathfinding (A*)
sub get_neighbors {
    my ( $node, $grid ) = @_;
    my ( $nx,   $ny )   = @$node;
    my @result;

    # Cardinals: Up, Down, Left, Right
    my @dirs = ( [ 0, -1 ], [ 0, 1 ], [ -1, 0 ], [ 1, 0 ] );
    for my $d (@dirs) {
        my $tx = $nx + $d->[0];
        my $ty = $ny + $d->[1];

        # Check bounds
        next if $tx < 0 || $tx >= $MAP_SIZE || $ty < 0 || $ty >= $MAP_SIZE;

        # Check Walls (Collision)
        next if $grid->[$ty][$tx]->{wall};
        push @result, [ $tx, $ty ];
    }
    return @result;
}

sub find_path {
    my ( $start_x, $start_y, $end_x, $end_y, $grid ) = @_;

    # Simple Priority Queue implementation would be better, but array works for small maps
    my @open_set = ( { x => $start_x, y => $start_y, g => 0, h => 0, p => undef } );
    my %closed_set;
    while (@open_set) {

        # Sort by f_score (g + h) - primitive priority queue
        @open_set = sort { ( $a->{g} + $a->{h} ) <=> ( $b->{g} + $b->{h} ) } @open_set;
        my $current = shift @open_set;
        my $k       = "$current->{x},$current->{y}";
        next if $closed_set{$k};
        $closed_set{$k} = 1;

        # Check success
        if ( $current->{x} == $end_x && $current->{y} == $end_y ) {
            my @path;
            my $temp = $current;
            while ($temp) {
                unshift @path, [ $temp->{x}, $temp->{y} ];
                $temp = $temp->{p};
            }
            return \@path;
        }

        # Neighbors
        for my $n ( get_neighbors( [ $current->{x}, $current->{y} ], $grid ) ) {
            next if $closed_set{"$n->[0],$n->[1]"};
            my $g_score = $current->{g} + 1;
            my $h_score = abs( $n->[0] - $end_x ) + abs( $n->[1] - $end_y );    # Manhattan distance
            push @open_set, { x => $n->[0], y => $n->[1], g => $g_score, h => $h_score, p => $current };
        }
    }
    return undef;                                                               # No path found
}

# Game State Initialization
# Attempt to use Vulkan driver for the Renderer if available
SDL_SetHint( "SDL_RENDER_DRIVER", "vulkan" );
die SDL_GetError() unless SDL_Init(SDL_INIT_VIDEO);
my $win = SDL_CreateWindow( 'Perl Sims 2 (Vulkan Backend)', $SCREEN_W, $SCREEN_H, SDL_WINDOW_RESIZABLE );
my $ren = SDL_CreateRenderer( $win, undef );
SDL_SetRenderDrawBlendMode( $ren, SDL_BLENDMODE_BLEND );

# World Generation
my @world;
my @objects;    # Furniture
for my $y ( 0 .. $MAP_SIZE - 1 ) {
    for my $x ( 0 .. $MAP_SIZE - 1 ) {
        $world[$y][$x] = { wall => 0 };

        # Add some random walls
        if ( $x == 0 || $y == 0 || $x == $MAP_SIZE - 1 || $y == $MAP_SIZE - 1 ) {
            $world[$y][$x]->{wall} = 1;
        }
        elsif ( $x == 5 && $y > 2 && $y < 8 ) {
            $world[$y][$x]->{wall} = 1;    # Internal wall
        }
    }
}

# Add a Fridge
push @objects, { type => 'fridge', x => 2, y => 2, color => [ 200, 200, 255 ] };

# The Sim
my $sim = {
    x           => 8.0,
    y           => 8.0,
    z           => 0.0,
    path        => [],                                # List of coordinate nodes to walk to
    target_node => undef,
    speed       => 0.08,
    color       => [ 255, 100, 100 ],
    needs       => { hunger => 60, energy => 100 },
    action      => 'Idle',
};

# Rendering Helpers
sub draw_poly {
    my ( $color, @points ) = @_;
    return unless @points == 4;                       # We only handle quads here for simplicity

    # Project all points
    my @screen_pts;
    for my $p (@points) {
        my ( $sx, $sy, $d ) = project_3d( $p->[0], $p->[1], $p->[2] );
        return unless defined $sx;                    # Clip if any point is behind camera
        push @screen_pts, [ $sx, $sy ];
    }
    # Construct Vertex Buffer for 2 Triangles (1 Quad)
    # 0, 1, 2, 0, 2, 3
    my @indices = ( 0, 1, 2, 0, 2, 3 );

    # Write the 6 vertices directly into the persistent buffer
    for my $i ( 0 .. 5 ) {
        my $v    = $indices[$i];
        my $pinx = $qv_px[$i];
        my $piny = $qv_py[$i];
        my $pinr = $qv_r[$i];
        my $ping = $qv_g[$i];
        my $pinb = $qv_b[$i];
        my $pina = $qv_a[$i];
        $$pinx = $screen_pts[$v]->[0];
        $$piny = $screen_pts[$v]->[1];
        $$pinr = $color->[0] / 255.0;
        $$ping = $color->[1] / 255.0;
        $$pinb = $color->[2] / 255.0;
        $$pina = 1.0;
    }
    SDL_RenderGeometry( $ren, undef, $quad_verts, 6, undef, 0 );
}

sub draw_cube {
    my ( $x, $y, $z, $w, $h, $d, $color ) = @_;

    # Colors for lighting
    my $top   = $color;
    my $side1 = [ map { $_ * 0.8 } @$color ];
    my $side2 = [ map { $_ * 0.6 } @$color ];

    # Top Face
    draw_poly( $top, [ $x, $y, $z + $h ], [ $x + $w, $y, $z + $h ], [ $x + $w, $y + $d, $z + $h ], [ $x, $y + $d, $z + $h ] );

    # Front Face
    draw_poly( $side1, [ $x, $y + $d, $z ], [ $x + $w, $y + $d, $z ], [ $x + $w, $y + $d, $z + $h ], [ $x, $y + $d, $z + $h ] );

    # Right Face
    draw_poly( $side2, [ $x + $w, $y, $z ], [ $x + $w, $y + $d, $z ], [ $x + $w, $y + $d, $z + $h ], [ $x + $w, $y, $z + $h ] );
}

#   Main Loop
my $running     = 1;
my $mouse_ptr_x = Affix::malloc(4);
my $mouse_ptr_y = Affix::malloc(4);
my $event_ptr   = Affix::malloc(128);
while ($running) {

    # Input
    while ( SDL_PollEvent($event_ptr) ) {
        my $ev = Affix::cast( $event_ptr, SDL_CommonEvent );
        if    ( $ev->{type} == SDL_EVENT_QUIT ) { $running = 0; }
        elsif ( $ev->{type} == SDL_EVENT_MOUSE_BUTTON_DOWN ) {
            my $b = Affix::cast( $event_ptr, SDL_MouseButtonEvent );
            if ( $b->{button} == SDL_BUTTON_LEFT ) {

                # Raycasting (Mouse picking) is hard in 3D.
                # Cheat: Loop through all floor tiles, project them, check collision with mouse.
                my $best_dist = 9999;
                my $target    = undef;

                # Check Fridge First
                for my $obj (@objects) {
                    my ( $sx, $sy, $depth ) = project_3d( $obj->{x} + 0.5, $obj->{y} + 0.5, 0.5 );
                    if ( defined $sx ) {
                        my $dist = ( $b->{x} - $sx )**2 + ( $b->{y} - $sy )**2;
                        if ( $dist < 1000 ) {    # Clicked object
                            $target    = { type => 'object', obj => $obj };
                            $best_dist = 0;                                   # Priority
                        }
                    }
                }

                # Check Floor
                if ( !$target ) {
                    for my $y ( 0 .. $MAP_SIZE - 1 ) {
                        for my $x ( 0 .. $MAP_SIZE - 1 ) {
                            next if $world[$y][$x]->{wall};
                            my ( $sx, $sy, $d ) = project_3d( $x + 0.5, $y + 0.5, 0 );
                            next unless defined $sx;
                            my $dist = ( $b->{x} - $sx )**2 + ( $b->{y} - $sy )**2;
                            if ( $dist < 900 && $d < $best_dist ) {    # < 30px radius
                                $best_dist = $d;
                                $target    = { type => 'floor', x => $x, y => $y };
                            }
                        }
                    }
                }

                # Resolve Action
                if ($target) {
                    my ( $tx, $ty );
                    if ( $target->{type} eq 'object' && $target->{obj}->{type} eq 'fridge' ) {
                        $tx                  = $target->{obj}->{x};
                        $ty                  = $target->{obj}->{y} + 1;    # Stand in front of it
                        $sim->{action_queue} = 'EAT';
                    }
                    else {
                        $tx                  = $target->{x};
                        $ty                  = $target->{y};
                        $sim->{action_queue} = undef;
                    }

                    # Calculate Path
                    my $path = find_path( int( $sim->{x} ), int( $sim->{y} ), $tx, $ty, \@world );
                    if ($path) {
                        $sim->{path}        = $path;
                        $sim->{target_node} = shift @{ $sim->{path} };    # Pop current pos
                        $sim->{target_node} = shift @{ $sim->{path} };    # First step
                        $sim->{action}      = "Walking";
                    }
                    else {
                        print "Can't reach that location!\n";
                    }
                }
            }
        }
        elsif ( $ev->{type} == SDL_EVENT_KEY_DOWN ) {
            my $k = Affix::cast( $event_ptr, SDL_KeyboardEvent );
            if ( $k->{scancode} == SDL_SCANCODE_LEFT )  { $camera->{yaw}   -= 0.1; }
            if ( $k->{scancode} == SDL_SCANCODE_RIGHT ) { $camera->{yaw}   += 0.1; }
            if ( $k->{scancode} == SDL_SCANCODE_UP )    { $camera->{pitch} += 0.05; }
            if ( $k->{scancode} == SDL_SCANCODE_DOWN )  { $camera->{pitch} -= 0.05; }
        }
    }

    #   Logic
    # Sim Path Following
    if ( $sim->{target_node} ) {
        my $tx   = $sim->{target_node}->[0] + 0.5;    # Center of tile
        my $ty   = $sim->{target_node}->[1] + 0.5;
        my $dx   = $tx - $sim->{x};
        my $dy   = $ty - $sim->{y};
        my $dist = sqrt( $dx * $dx + $dy * $dy );
        if ( $dist < 0.1 ) {

            # Reached Node
            $sim->{x}           = $tx;
            $sim->{y}           = $ty;
            $sim->{target_node} = shift @{ $sim->{path} };
            if ( !$sim->{target_node} ) {

                # Path Complete
                if ( $sim->{action_queue} eq 'EAT' ) {
                    $sim->{action} = "Eating";
                }
                else {
                    $sim->{action} = "Idle";
                }
            }
        }
        else {
            # Move
            $sim->{x} += ( $dx / $dist ) * $sim->{speed};
            $sim->{y} += ( $dy / $dist ) * $sim->{speed};
        }
    }

    # Sim Logic
    $sim->{needs}->{hunger} -= 0.02;
    if ( $sim->{action} eq 'Eating' ) {
        $sim->{needs}->{hunger} += 0.5;
        if ( $sim->{needs}->{hunger} >= 100 ) {
            $sim->{needs}->{hunger} = 100;
            $sim->{action}          = "Idle";
            $sim->{action_queue}    = undef;
        }
    }

    # Render
    SDL_SetRenderDrawColor( $ren, 30, 30, 40, 255 );
    SDL_RenderClear($ren);

    # Build Render Queue (Painter's Algorithm for 3D sorting)
    my @render_queue;

    # Floor & Walls
    for my $y ( 0 .. $MAP_SIZE - 1 ) {
        for my $x ( 0 .. $MAP_SIZE - 1 ) {

            # Calculate distance to camera for sorting
            # (Simple approximation using distance squared)
            my $dist = ( $x - $camera->{x} )**2 + ( $y - $camera->{y} )**2;

            # Floor
            push @render_queue, { type => 'floor', x => $x, y => $y, d => $dist };

            # Wall
            if ( $world[$y][$x]->{wall} ) {
                push @render_queue, { type => 'wall', x => $x, y => $y, d => $dist };
            }
        }
    }

    # Objects
    for my $obj (@objects) {
        my $dist = ( $obj->{x} - $camera->{x} )**2 + ( $obj->{y} - $camera->{y} )**2;
        push @render_queue, { type => 'obj', obj => $obj, d => $dist };
    }

    # Sim
    my $sim_dist = ( $sim->{x} - $camera->{x} )**2 + ( $sim->{y} - $camera->{y} )**2;
    push @render_queue, { type => 'sim', d => $sim_dist };

    # Sort: Furthest to Nearest
    @render_queue = sort { $b->{d} <=> $a->{d} } @render_queue;

    # Draw Loop
    foreach my $item (@render_queue) {
        if ( $item->{type} eq 'floor' ) {
            draw_poly(
                [ 50,             100,            50 ],
                [ $item->{x},     $item->{y},     0 ],
                [ $item->{x} + 1, $item->{y},     0 ],
                [ $item->{x} + 1, $item->{y} + 1, 0 ],
                [ $item->{x},     $item->{y} + 1, 0 ]
            );

            # Grid Outline
            my $pts = [
                [ $item->{x},     $item->{y},     0 ],
                [ $item->{x} + 1, $item->{y},     0 ],
                [ $item->{x} + 1, $item->{y} + 1, 0 ],
                [ $item->{x},     $item->{y} + 1, 0 ]
            ];

            # (Wireframe lines would go here, skipping for brevity)
        }
        elsif ( $item->{type} eq 'wall' ) {
            draw_cube( $item->{x}, $item->{y}, 0, 1, 1, 2, [ 150, 150, 150 ] );
        }
        elsif ( $item->{type} eq 'obj' ) {

            # Fridge (White Box)
            my $o = $item->{obj};
            draw_cube( $o->{x} + 0.1, $o->{y} + 0.1, 0, 0.8, 0.8, 1.8, $o->{color} );
        }
        elsif ( $item->{type} eq 'sim' ) {

            # Sim (Red stick figure / box)
            my $col = $sim->{color};
            draw_cube( $sim->{x} - 0.2, $sim->{y} - 0.2, 0, 0.4, 0.4, 1.7, $col );

            # Plumbob (Needs indicator)
            my $p_h   = 2.0;
            my $p_col = ( $sim->{needs}->{hunger} < 40 ) ? [ 255, 0, 0 ] : [ 0, 255, 0 ];
            draw_cube( $sim->{x} - 0.1, $sim->{y} - 0.1, $p_h, 0.2, 0.2, 0.4, $p_col );
        }
    }

    # UI Overlay (2D)
    SDL_SetRenderDrawColor( $ren, 255, 255, 255, 255 );
    SDL_RenderDebugText( $ren, 10, 10,  "Sim Action: " . $sim->{action} );
    SDL_RenderDebugText( $ren, 10, 30,  "Hunger: " . int( $sim->{needs}->{hunger} ) );
    SDL_RenderDebugText( $ren, 10, 730, "Arrows to Rotate Camera. Click ground to move. Click blue box to Eat." );
    SDL_RenderPresent($ren);
    SDL_Delay(16);
}

SDL_DestroyRenderer($ren);
SDL_DestroyWindow($win);
SDL_Quit();
