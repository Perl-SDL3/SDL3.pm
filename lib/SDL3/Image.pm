package SDL3::Image v0.0.1 {
    use v5.40;
    use base 'Exporter';
    use Affix qw[:all];
    use Alien::SDL3;
    use SDL3   qw[:all];
    use Carp   qw[croak confess];
    use Config qw[%Config];
    my $alien = Alien::SDL3->new;
    my $info  = $alien->alt('libsdl3_image')->package_info;
    croak 'SDL3_image is not installed' unless $info;
    my ($lib) = @{ $info->libfiles };
    $ENV{PATH} = join( $Config{path_sep}, ( map { @{ $_->bindirs // [] } } $info ), $ENV{PATH} // '' );
    our ( %EXPORT_TAGS, @EXPORT_OK );

    sub import ( $pkg, @wants ) {
        {
            no strict 'refs';
            (s[^:][_]r)->() for @wants;
        }
        require List::Util;
        @EXPORT_OK = sort map {@$_} values %EXPORT_TAGS;
        $EXPORT_TAGS{all} = [@EXPORT_OK];
        __PACKAGE__->export_to_level( 1, $pkg, @wants );
    }

    sub _affix_and_export ( $name, $args, $ret ) {
        my ( $n, $r ) = ref $name ? @$name : ( $name, $name );
        confess "Failed to affix $n" unless affix( $lib, $name, $args, $ret );
        push @{ $EXPORT_TAGS{ [ caller(1) ]->[3] =~ s/^.+?_//r } }, $n;
    }

    sub _const_and_export ( $name, $value ) {
        no strict 'refs';
        *{$name} = sub () {$value};
        push @{ $EXPORT_TAGS{ [ caller(1) ]->[3] =~ s/^.+?_//r } }, $name;
    }

    sub _func_and_export ( $name, $sub ) {
        no strict 'refs';
        *{$name} = $sub;
        push @{ $EXPORT_TAGS{ [ caller(1) ]->[3] =~ s/^.+?_//r } }, $name;
    }

    sub _typedef_and_export ( $name, $type //= () ) {
        no strict 'refs';
        if ( defined $type ) {
            typedef $name, $type;
        }
        else {
            typedef $name;
        }
        push @{ $EXPORT_TAGS{ [ caller(1) ]->[3] =~ s/^.+?_//r } }, $name;
    }

    sub _enum_and_export ( $name, $values ) {
        no strict 'refs';
        if ( defined $values ) {
            typedef $name, Enum [@$values];
            push @{ $EXPORT_TAGS{ [ caller(1) ]->[3] =~ s/^.+?_//r } }, $name;
            for my $enum (@$values) {
                push @{ $EXPORT_TAGS{ [ caller(1) ]->[3] =~ s/^.+?_//r } }, ref $enum ? $enum->[0] : $enum;
            }
        }
    }

=head3 C<:image> - SDL3_image Functions

All functions and constants provided by SDL3_image.

=cut

    sub _image () {
        state $done++ && return;

        # Runtime version discovery
        _affix_and_export IMG_Version => [], Int;
        _func_and_export IMG_VERSIONNUM       => sub ( $major, $minor, $patch ) { ( ($major) * 1000000 + ($minor) * 1000 + ($patch) ) };
        _func_and_export IMG_VERSIONNUM_MAJOR => sub ($version) { int( ($version) / 1000000 ) };
        _func_and_export IMG_VERSIONNUM_MINOR => sub ($version) { int( ( ($version) / 1000 ) % 1000 ) };
        _func_and_export IMG_VERSIONNUM_MICRO => sub ($version) { int( ($version) % 1000 ) };
        _func_and_export IMG_MAJOR_VERSION    => sub () { state $i //= IMG_VERSIONNUM_MAJOR( IMG_Version() ); $i };
        _func_and_export IMG_MINOR_VERSION    => sub () { state $i //= IMG_VERSIONNUM_MINOR( IMG_Version() ); $i };
        _func_and_export IMG_MICRO_VERSION    => sub () { state $i //= IMG_VERSIONNUM_MICRO( IMG_Version() ); $i };
        _const_and_export IMG_VERSION => IMG_VERSIONNUM( IMG_MAJOR_VERSION(), IMG_MINOR_VERSION(), IMG_MICRO_VERSION() );
        _func_and_export IMG_VERSION_ATLEAST => sub ( $X, $Y, $Z ) { ( IMG_VERSION() >= IMG_VERSIONNUM( $X, $Y, $Z ) ); };

        # Core loading
        _affix_and_export IMG_Load         => [String], Pointer [ SDL_Surface() ];
        _affix_and_export IMG_Load_IO      => [ Pointer [ SDL_IOStream() ], Bool ], Pointer [ SDL_Surface() ];
        _affix_and_export IMG_LoadTyped_IO => [ Pointer [ SDL_IOStream() ], Bool, String ], Pointer [ SDL_Surface() ];

        # Texture loading
        _affix_and_export IMG_LoadTexture => [ Pointer [ SDL_Renderer() ], String ], Pointer [ SDL_Texture() ];
        _affix_and_export IMG_LoadTexture_IO => [ Pointer [ SDL_Renderer() ], Pointer [ SDL_IOStream() ], Bool ], Pointer [ SDL_Texture() ];
        _affix_and_export
            IMG_LoadTextureTyped_IO => [ Pointer [ SDL_Renderer() ], Pointer [ SDL_IOStream() ], Bool, String ],
            Pointer [ SDL_Texture() ];
        if ( IMG_VERSION_ATLEAST( 3, 4, 0 ) ) {

            # GPU Texture loading
            _affix_and_export
                IMG_LoadGPUTexture => [ Pointer [ SDL_GPUDevice() ], Pointer [ SDL_GPUCopyPass() ], String, Pointer [Int], Pointer [Int] ],
                Pointer [ SDL_GPUTexture() ];
            _affix_and_export
                IMG_LoadGPUTexture_IO =>
                [ Pointer [ SDL_GPUDevice() ], Pointer [ SDL_GPUCopyPass() ], Pointer [ SDL3::SDL_IOStream() ], Bool, Pointer [Int], Pointer [Int] ],
                Pointer [ SDL_GPUTexture() ];
            _affix_and_export
                IMG_LoadGPUTextureTyped_IO => [
                Pointer [ SDL_GPUDevice() ],
                Pointer [ SDL_GPUCopyPass() ],
                Pointer [ SDL3::SDL_IOStream() ],
                Bool, String,
                Pointer [Int],
                Pointer [Int]
                ],
                Pointer [ SDL_GPUTexture() ];
            _affix_and_export IMG_GetClipboardImage => [], Pointer [ SDL3::SDL_Surface() ];
        }

        # Format detection
        for my $ext (qw[ANI AVIF CUR BMP GIF ICO JPG JXL LBM PCX PNG PNM QOI SVG TIF WEBP XCF XPM XV]) {
            _affix_and_export "IMG_is$ext", [ Pointer [ SDL3::SDL_IOStream() ] ], Bool;

            #~ _affix_and_export "IMG_Load${ext}_IO", [ Pointer [ SDL3::SDL_IOStream() ] ], Pointer [ SDL3::SDL_Surface() ] unless $ext eq 'SVG';
        }
        _affix_and_export IMG_LoadSVG_IO               => [ Pointer [ SDL3::SDL_IOStream() ] ], Pointer [ SDL_Surface() ];
        _affix_and_export IMG_LoadSizedSVG_IO          => [ Pointer [ SDL3::SDL_IOStream() ], Int, Int ], Pointer [ SDL_Surface() ];
        _affix_and_export IMG_ReadXPMFromArray         => [ Pointer [String] ], Pointer [ SDL_Surface() ];
        _affix_and_export IMG_ReadXPMFromArrayToRGB888 => [ Pointer [String] ], Pointer [ SDL_Surface() ];

        # Saving
        _affix_and_export IMG_Save         => [ Pointer [ SDL3::SDL_Surface() ], String ], Bool;
        _affix_and_export IMG_SaveTyped_IO => [ Pointer [ SDL3::SDL_Surface() ], Pointer [ SDL3::SDL_IOStream() ], Bool, String ], Bool;
        _affix_and_export IMG_SaveAVIF     => [ Pointer [ SDL3::SDL_Surface() ], String, Int ], Bool;
        _affix_and_export IMG_SaveAVIF_IO  => [ Pointer [ SDL3::SDL_Surface() ], Pointer [ SDL3::SDL_IOStream() ], Bool, Int ], Bool;
        _affix_and_export IMG_SaveBMP      => [ Pointer [ SDL3::SDL_Surface() ], String ], Bool;
        _affix_and_export IMG_SaveBMP_IO   => [ Pointer [ SDL3::SDL_Surface() ], Pointer [ SDL3::SDL_IOStream() ], Bool ], Bool;
        _affix_and_export IMG_SaveCUR      => [ Pointer [ SDL3::SDL_Surface() ], String ], Bool;
        _affix_and_export IMG_SaveCUR_IO   => [ Pointer [ SDL3::SDL_Surface() ], Pointer [ SDL3::SDL_IOStream() ], Bool ], Bool;
        _affix_and_export IMG_SaveGIF      => [ Pointer [ SDL3::SDL_Surface() ], String ], Bool;
        _affix_and_export IMG_SaveGIF_IO   => [ Pointer [ SDL3::SDL_Surface() ], Pointer [ SDL3::SDL_IOStream() ], Bool ], Bool;
        _affix_and_export IMG_SaveICO      => [ Pointer [ SDL3::SDL_Surface() ], String ], Bool;
        _affix_and_export IMG_SaveICO_IO   => [ Pointer [ SDL3::SDL_Surface() ], Pointer [ SDL3::SDL_IOStream() ], Bool ], Bool;
        _affix_and_export IMG_SaveJPG      => [ Pointer [ SDL3::SDL_Surface() ], String, Int ], Bool;
        _affix_and_export IMG_SaveJPG_IO   => [ Pointer [ SDL3::SDL_Surface() ], Pointer [ SDL3::SDL_IOStream() ], Bool, Int ], Bool;
        _affix_and_export IMG_SavePNG      => [ Pointer [ SDL3::SDL_Surface() ], String ], Bool;
        _affix_and_export IMG_SavePNG_IO   => [ Pointer [ SDL3::SDL_Surface() ], Pointer [ SDL3::SDL_IOStream() ], Bool ], Bool;
        _affix_and_export IMG_SaveTGA      => [ Pointer [ SDL3::SDL_Surface() ], String ], Bool;
        _affix_and_export IMG_SaveTGA_IO   => [ Pointer [ SDL3::SDL_Surface() ], Pointer [ SDL3::SDL_IOStream() ], Bool ], Bool;
        _affix_and_export IMG_SaveWEBP     => [ Pointer [ SDL3::SDL_Surface() ], String, Float ], Bool;
        _affix_and_export IMG_SaveWEBP_IO  => [ Pointer [ SDL3::SDL_Surface() ], Pointer [ SDL3::SDL_IOStream() ], Bool, Float ], Bool;

        # Animation Support
        _typedef_and_export IMG_Animation =>
            Struct [ w => Int, h => Int, count => Int, frames => Pointer [ Pointer [ SDL_Surface() ] ], delays => Pointer [Int] ];
        _affix_and_export IMG_LoadAnimation         => [String], Pointer [ IMG_Animation() ];
        _affix_and_export IMG_LoadAnimation_IO      => [ Pointer [ SDL_IOStream() ], Bool ], Pointer [ IMG_Animation() ];
        _affix_and_export IMG_LoadAnimationTyped_IO => [ Pointer [ SDL_IOStream() ], Bool, String ], Pointer [ IMG_Animation() ];
        for my $ext (qw[ANI APNG AVIF GIF WEBP]) {
            _affix_and_export "IMG_Load${ext}Animation_IO", [ Pointer [ SDL_IOStream() ] ], Pointer [ IMG_Animation() ];
            if ( $ext eq 'AVIF' || $ext eq 'WEBP' ) {
                _affix_and_export "IMG_Save${ext}Animation_IO", [ Pointer [ IMG_Animation() ], Pointer [ SDL_IOStream() ], Bool, Int ], Bool;
            }
            else {
                _affix_and_export "IMG_Save${ext}Animation_IO", [ Pointer [ IMG_Animation() ], Pointer [ SDL_IOStream() ], Bool ], Bool;
            }
        }
        _affix_and_export IMG_SaveAnimation         => [ Pointer [ IMG_Animation() ], String ], Bool;
        _affix_and_export IMG_SaveAnimationTyped_IO => [ Pointer [ IMG_Animation() ], Pointer [ SDL_IOStream() ], Bool, String ], Bool;
        _affix_and_export IMG_CreateAnimatedCursor  => [ Pointer [ IMG_Animation() ], Int, Int ], Pointer [ SDL_Cursor() ];
        _affix_and_export IMG_FreeAnimation         => [ Pointer [ IMG_Animation() ] ], Void;

        # Encoders
        _typedef_and_export IMG_AnimationEncoder => Void;
        _affix_and_export IMG_CreateAnimationEncoder    => [String], Pointer [ IMG_AnimationEncoder() ];
        _affix_and_export IMG_CreateAnimationEncoder_IO => [ Pointer [ SDL_IOStream() ], Bool, String ], Pointer [ IMG_AnimationEncoder() ];
        _affix_and_export IMG_CreateAnimationEncoderWithProperties => [ SDL_PropertiesID() ], Pointer [ IMG_AnimationEncoder() ];
        _const_and_export IMG_PROP_ANIMATION_ENCODER_CREATE_FILENAME_STRING             => 'SDL_image.animation_encoder.create.filename';
        _const_and_export IMG_PROP_ANIMATION_ENCODER_CREATE_IOSTREAM_POINTER            => 'SDL_image.animation_encoder.create.iostream';
        _const_and_export IMG_PROP_ANIMATION_ENCODER_CREATE_IOSTREAM_AUTOCLOSE_BOOLEAN  => 'SDL_image.animation_encoder.create.iostream.autoclose';
        _const_and_export IMG_PROP_ANIMATION_ENCODER_CREATE_TYPE_STRING                 => 'SDL_image.animation_encoder.create.type';
        _const_and_export IMG_PROP_ANIMATION_ENCODER_CREATE_QUALITY_NUMBER              => 'SDL_image.animation_encoder.create.quality';
        _const_and_export IMG_PROP_ANIMATION_ENCODER_CREATE_TIMEBASE_NUMERATOR_NUMBER   => 'SDL_image.animation_encoder.create.timebase.numerator';
        _const_and_export IMG_PROP_ANIMATION_ENCODER_CREATE_TIMEBASE_DENOMINATOR_NUMBER => 'SDL_image.animation_encoder.create.timebase.denominator';
        _const_and_export IMG_PROP_ANIMATION_ENCODER_CREATE_AVIF_MAX_THREADS_NUMBER     => 'SDL_image.animation_encoder.create.avif.max_threads';
        _const_and_export IMG_PROP_ANIMATION_ENCODER_CREATE_AVIF_KEYFRAME_INTERVAL_NUMBER =>
            'SDL_image.animation_encoder.create.avif.keyframe_interval';
        _const_and_export IMG_PROP_ANIMATION_ENCODER_CREATE_GIF_USE_LUT_BOOLEAN => 'SDL_image.animation_encoder.create.gif.use_lut';
        _affix_and_export IMG_AddAnimationEncoderFrame => [ Pointer [ IMG_AnimationEncoder() ], Pointer [ SDL_Surface() ], UInt64 ], Bool;
        _affix_and_export IMG_CloseAnimationEncoder => [ Pointer [ IMG_AnimationEncoder() ] ], Bool;

        # Decoders
        _enum_and_export IMG_AnimationDecoderStatus =>
            [ [ IMG_DECODER_STATUS_INVALID => -1 ], qw[IMG_DECODER_STATUS_OK IMG_DECODER_STATUS_FAILED IMG_DECODER_STATUS_COMPLETE] ];
        _typedef_and_export IMG_AnimationDecoder => Void;
        _affix_and_export IMG_CreateAnimationDecoder    => [String], Pointer [ IMG_AnimationDecoder() ];
        _affix_and_export IMG_CreateAnimationDecoder_IO => [ Pointer [ SDL_IOStream() ], Bool, String ], Pointer [ IMG_AnimationDecoder() ];
        _affix_and_export IMG_CreateAnimationDecoderWithProperties => [ SDL_PropertiesID() ], Pointer [ IMG_AnimationDecoder() ];
        _const_and_export IMG_PROP_ANIMATION_DECODER_CREATE_FILENAME_STRING             => 'SDL_image.animation_decoder.create.filename';
        _const_and_export IMG_PROP_ANIMATION_DECODER_CREATE_IOSTREAM_POINTER            => 'SDL_image.animation_decoder.create.iostream';
        _const_and_export IMG_PROP_ANIMATION_DECODER_CREATE_IOSTREAM_AUTOCLOSE_BOOLEAN  => 'SDL_image.animation_decoder.create.iostream.autoclose';
        _const_and_export IMG_PROP_ANIMATION_DECODER_CREATE_TYPE_STRING                 => 'SDL_image.animation_decoder.create.type';
        _const_and_export IMG_PROP_ANIMATION_DECODER_CREATE_TIMEBASE_NUMERATOR_NUMBER   => 'SDL_image.animation_decoder.create.timebase.numerator';
        _const_and_export IMG_PROP_ANIMATION_DECODER_CREATE_TIMEBASE_DENOMINATOR_NUMBER => 'SDL_image.animation_decoder.create.timebase.denominator';
        _const_and_export IMG_PROP_ANIMATION_DECODER_CREATE_AVIF_MAX_THREADS_NUMBER     => 'SDL_image.animation_decoder.create.avif.max_threads';
        _const_and_export IMG_PROP_ANIMATION_DECODER_CREATE_AVIF_ALLOW_INCREMENTAL_BOOLEAN =>
            'SDL_image.animation_decoder.create.avif.allow_incremental';
        _const_and_export IMG_PROP_ANIMATION_DECODER_CREATE_AVIF_ALLOW_PROGRESSIVE_BOOLEAN =>
            'SDL_image.animation_decoder.create.avif.allow_progressive';
        _const_and_export IMG_PROP_ANIMATION_DECODER_CREATE_GIF_TRANSPARENT_COLOR_INDEX_NUMBER =>
            'SDL_image.animation_encoder.create.gif.transparent_color_index';
        _const_and_export IMG_PROP_ANIMATION_DECODER_CREATE_GIF_NUM_COLORS_NUMBER => 'SDL_image.animation_encoder.create.gif.num_colors';
        _affix_and_export IMG_GetAnimationDecoderProperties => [ Pointer [ IMG_AnimationDecoder() ] ], SDL_PropertiesID();
        _const_and_export IMG_PROP_METADATA_IGNORE_PROPS_BOOLEAN => 'SDL_image.metadata.ignore_props';
        _const_and_export IMG_PROP_METADATA_DESCRIPTION_STRING   => 'SDL_image.metadata.description';
        _const_and_export IMG_PROP_METADATA_COPYRIGHT_STRING     => 'SDL_image.metadata.copyright';
        _const_and_export IMG_PROP_METADATA_TITLE_STRING         => 'SDL_image.metadata.title';
        _const_and_export IMG_PROP_METADATA_AUTHOR_STRING        => 'SDL_image.metadata.author';
        _const_and_export IMG_PROP_METADATA_CREATION_TIME_STRING => 'SDL_image.metadata.creation_time';
        _const_and_export IMG_PROP_METADATA_FRAME_COUNT_NUMBER   => 'SDL_image.metadata.frame_count';
        _const_and_export IMG_PROP_METADATA_LOOP_COUNT_NUMBER    => 'SDL_image.metadata.loop_count';
        _affix_and_export
            IMG_GetAnimationDecoderFrame => [ Pointer [ IMG_AnimationDecoder() ], Pointer [ Pointer [ SDL_Surface() ] ], Pointer [UInt64] ],
            Bool;
        _affix_and_export IMG_GetAnimationDecoderStatus => [ Pointer [ IMG_AnimationDecoder() ] ], IMG_AnimationDecoderStatus();
        _affix_and_export IMG_ResetAnimationDecoder     => [ Pointer [ IMG_AnimationDecoder() ] ], Bool;
        _affix_and_export IMG_CloseAnimationDecoder     => [ Pointer [ IMG_AnimationDecoder() ] ], Bool;
    }

    sub _all () {
        state $done++ && return;
        _image();
    }
}
1;
