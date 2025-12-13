use v5.40;
use Test2::V0 '!subtest';
use Test2::Util::Importer 'Test2::Tools::Subtest' => ( subtest_streamed => { -as => 'subtest' } );
use lib 'lib', '../lib', 'blib/lib', '../blib/lib';
use SDL3 qw[:all];
#
ok $SDL3::VERSION, 'SDL3::VERSION: ' . $SDL3::VERSION;
subtest ':version' => sub {
    imported_ok qw[
        SDL_GetVersion SDL_MAJOR_VERSION SDL_MINOR_VERSION SDL_MICRO_VERSION
        SDL_VERSIONNUM SDL_VERSIONNUM_MAJOR SDL_VERSIONNUM_MINOR SDL_VERSIONNUM_MICRO
        SDL_VERSION SDL_VERSION_ATLEAST
    ];
    diag 'SDL_GetVersion() == ' . SDL_GetVersion();
    is SDL_MAJOR_VERSION(), 3, 'we should be using SDL3';
    diag 'SDL_MAJOR_VERSION == ' . SDL_MAJOR_VERSION();
    diag 'SDL_MINOR_VERSION == ' . SDL_MINOR_VERSION();
    diag 'SDL_MICRO_VERSION == ' . SDL_MICRO_VERSION();
    is SDL_VERSIONNUM( 1, 2, 3 ), '1002003', 'SDL_VERSIONNUM(1, 2, 3)';
    is SDL_VERSIONNUM( SDL_MAJOR_VERSION, SDL_MINOR_VERSION, SDL_MICRO_VERSION ), SDL_GetVersion(),
        'SDL_VERSIONNUM(SDL_MAJOR_VERSION, SDL_MINOR_VERSION, SDL_MICRO_VERSION)';
    is SDL_VERSION(), SDL_GetVersion(), 'SDL_VERSION()';
    is SDL_VERSION_ATLEAST( SDL_MAJOR_VERSION, SDL_MINOR_VERSION, SDL_MICRO_VERSION ), T(),
        'SDL_VERSION_ATLEAST( SDL_MAJOR_VERSION, SDL_MINOR_VERSION, SDL_MICRO_VERSION ) == true';
    is SDL_VERSION_ATLEAST( SDL_MAJOR_VERSION, SDL_MINOR_VERSION, SDL_MICRO_VERSION() + 10 ), F(),
        'SDL_VERSION_ATLEAST( SDL_MAJOR_VERSION, SDL_MINOR_VERSION, SDL_MICRO_VERSION + 10 ) == false';
};
#
done_testing;
