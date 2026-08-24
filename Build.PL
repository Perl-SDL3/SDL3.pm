use v5.40;
use Module::Build;
my $class = Module::Build->subclass( class => 'SDL3::Builder', code => <<'' );
use v5.40;
sub ACTION_code ($self) {
    $self->SUPER::ACTION_code();
    say 'Now, update repo and install from xrepo!';
    require Alien::Xrepo;
    # Initialize
    my $repo = Alien::Xrepo->new();
    use Data::Dumper;
    # Add a custom repository (optional)
    # $repo->add_repo( 'my-repo', 'https://github.com/my/repo.git' );
    $repo->update_repo;
    # Install a shared lib with an automatic configuration
    for my $lib ( map { $repo->install($_) } qw[libsdl3 libsdl3_mixer libsdl3_image] ) {
        say $lib->libpath;
        #~ say $lib->kind;
        #~ say $lib->installdir;
        say Dumper $lib->includedirs;
        say Dumper $lib->libfiles;
        say $lib->license;
        say $lib->version;
        say Dumper $lib->bindirs;
        say '-' x 10;
    }
}

my $build = $class->new( module_name => 'SDL3', license => 'artistic_2', dist_author => 'Sanko Robinson', requires => { Carp => 0 } );
$build->create_build_script;
