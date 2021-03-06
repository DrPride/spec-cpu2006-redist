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
#   $Id: Form.pm,v 2.0 2005/11/16 02:18:23 areibens Exp $
#
#=======================================================================
package PDF::API2::Resource::XObject::Form;

BEGIN {

    use PDF::API2::Util;
    use PDF::API2::Basic::PDF::Utils;
    use PDF::API2::Resource::XObject;

    use POSIX;

    use vars qw(@ISA $VERSION);

    @ISA = qw( PDF::API2::Resource::XObject );

    ( $VERSION ) = sprintf '%i.%03i', split(/\./,('$Revision: 2.0 $' =~ /Revision: (\S+)\s/)[0]); # $Date: 2005/11/16 02:18:23 $

}
no warnings qw[ deprecated recursion uninitialized ];

=item $res = PDF::API2::Resource::XObject::Form->new $pdf

Returns a form-resource object. base class for all types of form-xobjects.

=cut

sub new {
    my ($class,$pdf) = @_;
    my $self;

    $class = ref $class if ref $class;

    $self=$class->SUPER::new($pdf,pdfkey());
    $pdf->new_obj($self) unless($self->is_obj($pdf));

    $self->subtype('Form');
    $self->{FormType}=PDFNum(1);

    $self->{' apipdf'}=$pdf;

    return($self);
}

=item $res = PDF::API2::Resource::XObject::Form->new_api $api, $name

Returns a form resource object. This method is different from 'new' that
it needs an PDF::API2-object rather than a Text::PDF::File-object.

=cut

sub new_api {
    my ($class,$api,@opts)=@_;

    my $obj=$class->new($api->{pdf},@opts);
    $obj->{' api'}=$api;

    return($obj);
}

=item ($llx, $lly, $urx, $ury) = $res->bbox $llx, $lly, $urx, $ury

=cut

sub bbox {
    my $self = shift @_;
    my @b;
    if(@b=@_){
        $self->{BBox}=PDFArray(map { PDFNum($_) } @b);
    }
    @b=$self->{BBox}->elementsof;
    return(map { $_->val } @b);
}

=item $res->resource $type, $key, $obj

Adds a resource to the form.

B<Example:>

    $res->resource('Font',$fontkey,$fontobj);
    $res->resource('XObject',$imagekey,$imageobj);
    $res->resource('Shading',$shadekey,$shadeobj);
    $res->resource('ColorSpace',$spacekey,$speceobj);

B<Note:> You only have to add the required resources, if
they are NOT handled by the *font*, *image*, *shade* or *space*
methods.

=cut

sub resource {
    my ($self, $type, $key, $obj, $force) = @_;
    # we are a self-contained content stream.

    $self->{Resources}||=PDFDict();

    my $dict=$self->{Resources};
    $dict->realise if(ref($dict)=~/Objind$/);

    $dict->{$type}||= PDFDict();
    $dict->{$type}->realise if(ref($dict->{$type})=~/Objind$/);
    unless (defined $obj) {
        return($dict->{$type}->{$key} || undef);
    } else {
        if($force) {
            $dict->{$type}->{$key}=$obj;
        } else {
            $dict->{$type}->{$key}||= $obj;
        }
        return($dict);
    }
}

sub outobjdeep {
    my ($self, @opts) = @_;
    foreach my $k (qw/ api apipdf /) {
        $self->{" $k"}=undef;
        delete($self->{" $k"});
    }
    $self->SUPER::outobjdeep(@opts);
}


1;

__END__

=head1 AUTHOR

alfred reibenschuh

=head1 HISTORY

    $Log: Form.pm,v $
    Revision 2.0  2005/11/16 02:18:23  areibens
    revision workaround for SF cvs import not to screw up CPAN

    Revision 1.2  2005/11/16 01:27:50  areibens
    genesis2

    Revision 1.1  2005/11/16 01:19:27  areibens
    genesis

    Revision 1.10  2005/06/17 19:44:03  fredo
    fixed CPAN modulefile versioning (again)

    Revision 1.9  2005/06/17 18:53:34  fredo
    fixed CPAN modulefile versioning (dislikes cvs)

    Revision 1.8  2005/03/14 22:01:30  fredo
    upd 2005

    Revision 1.7  2004/12/16 00:30:54  fredo
    added no warn for recursion

    Revision 1.6  2004/06/15 09:14:54  fredo
    removed cr+lf

    Revision 1.5  2004/06/07 19:44:44  fredo
    cleaned out cr+lf for lf

    Revision 1.4  2003/12/08 13:06:08  Administrator
    corrected to proper licencing statement

    Revision 1.3  2003/11/30 17:33:27  Administrator
    merged into default

    Revision 1.2.2.1  2003/11/30 16:57:09  Administrator
    merged into default

    Revision 1.2  2003/11/30 11:47:14  Administrator
    added CVS id/log


=cut