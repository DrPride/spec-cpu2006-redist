#=======================================================================
#    ____  ____  _____              _    ____ ___   ____
#   |  _ \|  _ \|  ___|  _   _     / \  |  _ \_ _| |___ \
#   | |_) | | | | |_    (_) (_)   / _ \ | |_) | |    __) |
#   |  __/| |_| |  _|    _   _   / ___ \|  __/| |   / __/
#   |_|   |____/|_|     (_) (_) /_/   \_\_|  |___| |_____|
#
#   A Perl Module Chain to faciliate the Creation and Modification
#   of High-Quality "Portable Document Format (PDF)" Files.
#
#   Copyright 1999-2005 Alfred Reibenschuh <areibens@cpan.org>.
#
#=======================================================================
#
#   This library is free software; you can redistribute it and/or
#   modify it under the terms of the GNU Lesser General Public
#   License as published by the Free Software Foundation; either
#   version 2 of the License, or (at your option) any later version.
#
#   This library is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#   Lesser General Public License for more details.
#
#   You should have received a copy of the GNU Lesser General Public
#   License along with this library; if not, write to the
#   Free Software Foundation, Inc., 59 Temple Place - Suite 330,
#   Boston, MA 02111-1307, USA.
#
#   $Id: Postscript.pm,v 2.2 2007/06/27 20:54:16 areibens Exp $
#
#=======================================================================
package PDF::API2::Resource::Font::Postscript;

BEGIN {

    use utf8;
    use Encode qw(:all);
    use PDF::API2::Util;
    use PDF::API2::Basic::PDF::Utils;
    use PDF::API2::Resource::Font;

    use POSIX;
    use Compress::Zlib;
    use File::Find;
    use IO::File qw();
    use vars qw(@ISA $VERSION);

    @ISA = qw( PDF::API2::Resource::Font );

    ( $VERSION ) = sprintf '%i.%03i', split(/\./,('$Revision: 2.2 $' =~ /Revision: (\S+)\s/)[0]); # $Date: 2007/06/27 20:54:16 $

}
no warnings qw[ deprecated recursion uninitialized ];

=item $font = PDF::API2::Resource::Font::Postscript->new @parameters

Returns a adobe type1 font object (called from $pdf->psfont).

=cut

sub new {
    my ($class, $pdf, $psfile, %opts) = @_;
    my ($self,$encoding);
    my (@w,$data);

    if(defined $opts{-afmfile}) {
        $data = $class->readAFM($opts{-afmfile});
    } elsif(defined $opts{-pfmfile}) {
        $data = $class->readPFM($opts{-pfmfile});
    } elsif(defined $opts{-xfmfile}) {
        $data = $class->readXFM($opts{-xfmfile});
    } else {
        die "no proper font-metrics file specified for '$psfile'.";
    }

    $class = ref $class if ref $class;
    $self = $class->SUPER::new($pdf, $data->{apiname}.pdfkey().'~'.time());
    $pdf->new_obj($self) unless($self->is_obj($pdf));
    $self->{' data'}=$data;

    if($opts{-pdfname}) {
        $self->name($opts{-pdfname});
    }

    $self->{'Subtype'} = PDFName("Type1");
    $self->{'FontDescriptor'}=$self->descrByData();
    if(-f $psfile)
    {
        $self->{'BaseFont'} = PDFName(pdfkey().'+'.($self->fontname).'~'.time());

        my ($l1,$l2,$l3,$stream)=$self->readPFAPFB($psfile);

        my $s = PDFDict();
        $self->{'FontDescriptor'}->{'FontFile'} = $s;
        $s->{'Length1'} = PDFNum($l1);
        $s->{'Length2'} = PDFNum($l2);
        $s->{'Length3'} = PDFNum($l3);
        $s->{'Filter'} = PDFArray(PDFName("FlateDecode"));
        $s->{' stream'} = $stream;
        if(defined $pdf) {
            $pdf->new_obj($s);
        }
    }
    else
    {
        $self->{'BaseFont'} = PDFName($self->fontname);
    }

    $self->encodeByData($opts{-encode});

    $self->{-nocomps}=1 if($opts{-nocomps});
    $self->{-dokern}=1 if($opts{-dokern});
    
    return($self);
}

sub new_api {
    my ($class, $api, @para) = @_;

    $class = ref $class if ref $class;
    my $self = $class->new($api->{pdf},@para);

    $self->{' apipdf'}=$api->{pdf};
    $self->{' api'}=$api;

    return($self);
}

sub readPFAPFB {
    my ($self,$file) = @_;
    my ($l1,$l2,$l3,$stream,$t1stream,@lines,$line,$head,$body,$tail);

    die "cannot find font '$file' ..." unless(-f $file);

    $l=-s $file;

    open(INF,$file);
    binmode(INF,':raw');
    read(INF,$line,2);
    @lines=unpack('C*',$line);
    if(($lines[0]==0x80) && ($lines[1]==1)) {
        read(INF,$line,4);
        $l1=unpack('V',$line);
        seek(INF,$l1,1);
        read(INF,$line,2);
        @lines=unpack('C*',$line);
        if(($lines[0]==0x80) && ($lines[1]==2)) {
            read(INF,$line,4);
            $l2=unpack('V',$line);
        } else {
            die "corrupt pfb in file '$file' at marker='2'.";
        }
        seek(INF,$l2,1);
        read(INF,$line,2);
        @lines=unpack('C*',$line);
        if(($lines[0]==0x80) && ($lines[1]==1)) {
            read(INF,$line,4);
            $l3=unpack('V',$line);
        } else {
            die "corrupt pfb in file '$file' at marker='3'.";
        }
        seek(INF,0,0);
        @lines=<INF>;
        close(INF);
        $stream=join('',@lines);
        $t1stream=substr($stream,6,$l1);
        $t1stream.=substr($stream,12+$l1,$l2);
        $t1stream.=substr($stream,18+$l1+$l2,$l3);
    } elsif($line eq '%!') {
        seek(INF,0,0);
        while($line=<INF>) {
            if(!$l1) {
                $head.=$line;
                if($line=~/eexec$/){
                    chomp($head);
                    $head.="\x0d";
                    $l1=length($head);
                }
            } elsif(!$l2) {
                if($line=~/^0+$/) {
                    $l2=length($body);
                    $tail=$line;
                } else {
                    chomp($line);
                    $body.=pack('H*',$line);
                }
            } else {
                $tail.=$line;
            }
        }
        $l3=length($tail);
        $t1stream="$head$body$tail";
    } else {
        die "unsupported font-format in file '$file' at marker='1'.";
    }

    return($l1,$l2,$l3,$t1stream);
}


# $datahashref = $self->readAFM( $afmfile );

sub readAFM 
{
    my ($self,$file)=@_;
    my $data={};
    $data->{wx}={};
    $data->{bbox}={};
    $data->{char}=[];
    $data->{firstchar}=255;
    $data->{lastchar}=0;

    if(! -e $file) {die "file='$file' not existant.";}
    open(AFMF, $file) or die "Can't find the AFM file for $file";
    local($/, $_) = ("\n", undef);  # ensure correct $INPUT_RECORD_SEPARATOR
    while ($_=<AFMF>) 
    {
        if (/^StartCharMetrics/ .. /^EndCharMetrics/) 
        {
        # only lines that start with "C" or "CH" are parsed
            next unless $_=~/^CH?\s/;
            my($ch)   = $_=~/^CH?\s+(\d+)\s*;/;
            $ch=$ch||0;
            my($name) = $_=~/\bN\s+(\.?\w+)\s*;/;
            my($wx)   = $_=~/\bWX\s+(\d+)\s*;/;
            my($bbox)    = $_=~/\bB\s+([^;]+);/;
            $bbox =~ s/\s+$//;
            # Should also parse lingature data (format: L successor lignature)
            $data->{avgwidth2} += $wx ;
            $data->{maxwidth} = $data->{maxwidth}<$wx ? $wx : $data->{maxwidth};
            $data->{wx}->{$name} = $wx ;
            $data->{bbox}->{$name} = [split(/\s+/,$bbox)];
            if($ch>0) {
                $data->{'char'}->[$ch]=$name ;
            }
            $data->{lastchar} = $data->{lastchar}<$ch ? $ch : $data->{lastchar};
            $data->{firstchar} = $data->{firstchar}>$ch ? $ch : $data->{firstchar};
            next;
        }
        elsif(/^StartKernData/ .. /^EndKernData/)
        {
            $data->{kern}||={};
            if($_=~m|^KPX\s+(\S+)\s+(\S+)\s+(\S+)\s*$|i)
            {
                $data->{kern}->{"$1:$2"}=$3;    
            }
        }
        elsif(/^StartComposites/ .. /^EndComposites/)
        {
            $data->{comps}||={}; 
            if($_=~m|^CC\s+(\S+)\s+(\S+)\s+;|i)
            {
                my ($name,$comp)=($1,$2);
                my @cv=split(/;/,$_);
                shift @cv;
                my $rng=[];
                foreach (1..$comp)
                {
                    my @c1=split(/\s+/,shift @cv);
                    push @{$rng},$c1[1],$c1[2],$c1[3];
                }
                $data->{comps}->{$name}=$rng;    
            }
        }
        last if $_=~/^EndFontMetrics/;
        if (/(^\w+)\s+(.*)/) 
        {
            my($key,$val) = ($1, $2);
            $key = lc $key;
            if (defined $data->{$key}) 
            {
            #   $data->{$key} = [ $data->{$key} ] unless ref $data->{$key};
            #   push(@{$data->{$key}}, $val);
            } 
            else 
            {
                $val=~s/[\x00\x1f]+//g;
                $data->{$key} = $val;
            }
        } 
        else 
        {
                ## print STDERR "Can't parse: $_";
        }
    }
    close(AFMF);
    unless (exists $data->{wx}->{'.notdef'}) 
    {
        $data->{wx}->{'.notdef'} = 0;
        $data->{bbox}{'.notdef'} = [0, 0, 0, 0];
    }

    $data->{avgwidth2} /= scalar keys %{$data->{bbox}} ;
    $data->{avgwidth2} = int($data->{avgwidth2});

    $data->{fontname}=~s/[\x00-\x20]+//og;
    ## $data->{fontname}=~s/[^A-Za-z0-9]+//og;

    if(defined $data->{fullname}) 
    {
        $data->{altname}=$data->{fullname};
    } 
    else 
    {
        $data->{altname}=$data->{familyname};
        $data->{altname}.=' Italic' if($data->{italicangle}<0);
        $data->{altname}.=' Oblique' if($data->{italicangle}>0);
        $data->{altname}.=' '.$data->{weight};
    }
    $data->{apiname}=$data->{altname};
    $data->{altname}=~s/[^A-Za-z0-9]+//og;

    $data->{subname}=$data->{weight};
    $data->{subname}.=' Italic' if($data->{italicangle}<0);
    $data->{subname}.=' Oblique' if($data->{italicangle}>0);
    $data->{subname}=~s/[^A-Za-z0-9]+//og;

    $data->{missingwidth}||=$data->{avgwidth2};

    $data->{issymbol} = 0;
    $data->{fontbbox} = [ split(/\s+/,$data->{fontbbox}) ];

    $data->{apiname}=join('',map { $_=~s/[^A-Za-z0-9]+//og; $_=ucfirst(lc(substr($_,0,2))); $_; } split(/\s+/,$data->{apiname}));

    $data->{flags} = 34;

    $data->{uni}||=[];
    foreach my $n (0..255) 
    {
        $data->{uni}->[$n]=uniByName($data->{char}->[$n] || '.notdef') || 0;
    }
    delete $data->{bbox};
    
    return($data);
}

sub readPFM {
    my ($self,$file)=@_;
    if(! -e $file) {die "pfmfile='$file' not existant.";}
    my $fh=IO::File->new();
    my $data={};

    $data->{issymbol} = 0;

    $data->{wx}={};
    $data->{bbox}={};
    $data->{kern}={};
    $data->{char}=[];

    my $buf;
    open($fh,$file) || return undef;
    binmode($fh,':raw');
    read($fh,$buf,117 + 30);

    my %df;
    # Packing structure for PFM Header
    (   $df{Version},
        $df{Size},
        $df{Copyright},
        $df{Type},
        $df{Point},
        $df{VertRes},
        $df{HorizRes},
        $df{Ascent},
        $df{InternalLeading},
        $df{ExternalLeading},
        $df{Italic},
        $df{Underline},
        $df{StrikeOut},
        $df{Weight},
#define FW_DONTCARE 0
#define FW_THIN 100
#define FW_EXTRALIGHT   200
#define FW_ULTRALIGHT   FW_EXTRALIGHT
#define FW_LIGHT    300
#define FW_NORMAL   400
#define FW_REGULAR  400
#define FW_MEDIUM   500
#define FW_SEMIBOLD 600
#define FW_DEMIBOLD FW_SEMIBOLD
#define FW_BOLD 700
#define FW_EXTRABOLD    800
#define FW_ULTRABOLD    FW_EXTRABOLD
#define FW_HEAVY    900
#define FW_BLACK    FW_HEAVY
        $df{CharSet},
#define ANSI_CHARSET    0
#define DEFAULT_CHARSET 1
#define SYMBOL_CHARSET  2
#define SHIFTJIS_CHARSET    128
#define HANGEUL_CHARSET 129
#define HANGUL_CHARSET  129
#define GB2312_CHARSET  134
#define CHINESEBIG5_CHARSET 136
#define GREEK_CHARSET   161
#define TURKISH_CHARSET 162
#define HEBREW_CHARSET  177
#define ARABIC_CHARSET  178
#define BALTIC_CHARSET  186
#define RUSSIAN_CHARSET 204
#define THAI_CHARSET    222
#define EASTEUROPE_CHARSET  238
#define OEM_CHARSET 255
#define JOHAB_CHARSET   130
#define VIETNAMESE_CHARSET  163
#define MAC_CHARSET 77
#define BALTIC_CHARSET 186
#define JOHAB_CHARSET 130
#define VIETNAMESE_CHARSET 163
        $df{PixWidth},
        $df{PixHeight},
        $df{PitchAndFamily},
#define DEFAULT_PITCH   0
#define FIXED_PITCH 1
#define VARIABLE_PITCH  2
#define MONO_FONT 8
#define FF_DECORATIVE   80
#define FF_DONTCARE 0
#define FF_MODERN   48
#define FF_ROMAN    16
#define FF_SCRIPT   64
#define FF_SWISS    32
        $df{AvgWidth},
        $df{MaxWidth},
        $df{FirstChar},
        $df{LastChar},
        $df{DefaultChar},
        $df{BreakChar},
        $df{WidthBytes},
        $df{Device},
        $df{Face},
        $df{BitsPointer},
        $df{BitsOffset},
        $df{SizeFields},        # Two bytes, the size of extension section
        $df{ExtMetricsOffset},  # Four bytes, offset value to the 'Extended Text Metrics' section
        $df{ExtentTable},       # Four bytes Offset value to the Extent Table
        $df{OriginTable},       # Four bytes 0
        $df{PairKernTable},     # Four bytes 0
        $df{TrackKernTable},    # Four bytes 0
        $df{DriverInfo},        # Four bytes Offset value to the PostScript font name string
        $df{Reserved},          # Four bytes 0
    ) = unpack("vVa60vvvvvvvCCCvCvvCvvCCCCvVVVV vVVVVVVV",$buf); # PFM Header + Ext

    seek($fh,$df{Device},0);
    read($fh,$buf,250);

    ($df{postScript}) = unpack("Z*",$buf);
    $buf=substr($buf,length($df{postScript})+1,250);
    ($df{windowsName}) = unpack("Z*",$buf);
    $buf=substr($buf,length($df{windowsName})+1,250);
    ($df{psName}) = unpack("Z*",$buf);

    seek($fh,$df{ExtMetricsOffset},0);
    read($fh,$buf,52);

    (   $df{etmSize},
        $df{PointSize},
        $df{Orientation},
        $df{MasterHeight},
        $df{MinScale},
        $df{MaxScale},
        $df{MasterUnits},
        $df{CapHeight},
        $df{xHeight},
        $df{LowerCaseAscent},
        $df{LowerCaseDescent},
        $df{Slant},
        $df{SuperScript},
        $df{SubScript},
        $df{SuperScriptSize},
        $df{SubScriptSize},
        $df{UnderlineOffset},
        $df{UnderlineWidth},
        $df{DoubleUpperUnderlineOffset},
        $df{DoubleLowerUnderlineOffset},
        $df{DoubleUpperUnderlineWidth},
        $df{DoubleLowerUnderlineWidth},
        $df{StrikeOutOffset},
        $df{StrikeOutWidth},
        $df{KernPairs},
        $df{KernTracks} ) = unpack('v*',$buf);

#use Data::Dumper;
#    print STDERR Dumper(\%df);
    $data->{fontname}=$df{psName};
    $data->{fontname}=~s/[^A-Za-z0-9]+//og;
    $data->{apiname}=$df{windowsName};
    $data->{apiname}=join('',map { $_=~s/[^A-Za-z0-9]+//og; $_=ucfirst(lc(substr($_,0,2))); $_; } split(/\s+/,$data->{apiname}));

    $data->{upem}=1000;

    $data->{fontbbox}=[-100,-100,$df{MaxWidth},$df{Ascent}];

    $data->{stemv}=0;
    $data->{stemh}=0;

    $data->{lastchar}=$df{LastChar};
    $data->{firstchar}=$df{FirstChar};

    $data->{missingwidth}=$df{AvgWidth};
    $data->{maxwidth}=$df{MaxWidth};
    $data->{ascender}=$df{Ascent};
    $data->{descender}=-$df{LowerCaseDescent};

    $data->{flags} = 0;
    # FixedPitch 1
    $data->{flags} |= 1 if((($df{PitchAndFamily} & 1) || ($df{PitchAndFamily} & 8)) && !($df{PitchAndFamily} & 2));
    # Serif 2
    $data->{flags} |= 2 if(($df{PitchAndFamily} & 16) && !($df{PitchAndFamily} & 32));
    # Symbolic 4
    $data->{flags} |= 4 if($df{PitchAndFamily} & 80);
    # Script 8
    $data->{flags} |= 8 if($df{PitchAndFamily} & 64);
    # Nonsymbolic   32
    $data->{flags} |= 32 unless($df{PitchAndFamily} & 80);
    # Italic 64
    $data->{flags} |= 64 if($df{Italic});

    #bit 17 AllCap
    #bit 18 SmallCap
    #bit 19 ForceBold

    $data->{capheight}=$df{CapHeight};
    $data->{xheight}=$df{xHeight};

    $data->{uni}=[ unpack('U*',decode('cp1252',pack('C*',(0..255)))) ];
    $data->{char}=[ map { nameByUni($_) || '.notdef' } @{$data->{uni}} ];

    $data->{italicangle}=-12*$df{Italic};
    $data->{isfixedpitch}=(($df{PitchAndFamily} & 8) || ($df{PitchAndFamily} & 1));
    $data->{underlineposition}=-$df{UnderlineOffset};
    $data->{underlinethickness}=$df{UnderlineWidth};

    seek($fh,$df{ExtentTable},0);

    foreach my $k ($df{FirstChar} .. $df{LastChar}) {
        read($fh,$buf,2);
        my ($wx)=unpack('v',$buf);
        $data->{wx}->{$data->{char}->[$k]}=$wx;
#        print STDERR "e: c=$k n='".$data->{char}->[$k]."' wx='$wx'\n";
    }
    $data->{pfm}=\%df;
    close($fh);

    return($data);
}

sub readXFM {
    my ($class,$xfmfile) = @_;
    die "cannot find font '$xfmfile' ..." unless(-f $xfmfile);

    my $data={};

    return($data);
}


1;

__END__

=head1 HISTORY

    $Log: Postscript.pm,v $
    Revision 2.2  2007/06/27 20:54:16  areibens
    fix exporter warnings of IO::File

    Revision 2.1  2006/08/14 18:08:16  areibens
    moved "use io-file" to begin section

    Revision 2.0  2005/11/16 02:18:14  areibens
    revision workaround for SF cvs import not to screw up CPAN

    Revision 1.2  2005/11/16 01:27:50  areibens
    genesis2

    Revision 1.1  2005/11/16 01:19:27  areibens
    genesis

    Revision 1.13  2005/10/19 23:05:17  fredo
    silenced 'cannot parse' since it is usually no error

    Revision 1.12  2005/10/19 19:12:35  fredo
    added handling of optional kerning

    Revision 1.11  2005/10/01 23:38:00  fredo
    added kerning+composite parsing
    added nonembedding check

    Revision 1.10  2005/10/01 22:41:07  fredo
    fixed font-naming race condition for multiple document updates

    Revision 1.9  2005/06/17 19:44:03  fredo
    fixed CPAN modulefile versioning (again)

    Revision 1.8  2005/06/17 18:53:34  fredo
    fixed CPAN modulefile versioning (dislikes cvs)

    Revision 1.7  2005/03/14 22:01:28  fredo
    upd 2005

    Revision 1.6  2004/12/16 00:30:54  fredo
    added no warn for recursion

    Revision 1.5  2004/06/15 09:14:53  fredo
    removed cr+lf

    Revision 1.4  2004/06/07 19:44:43  fredo
    cleaned out cr+lf for lf

    Revision 1.3  2003/12/08 13:06:01  Administrator
    corrected to proper licencing statement

    Revision 1.2  2003/11/30 17:32:48  Administrator
    merged into default

    Revision 1.1.1.1.2.2  2003/11/30 16:57:05  Administrator
    merged into default

    Revision 1.1.1.1.2.1  2003/11/30 14:45:22  Administrator
    added CVS id/log


 =head1 AUTHOR

alfred reibenschuh

=cut

