package HTML::FormHandler::Field::Radio;
# ABSTRACT: not used

use Moose;
extends 'HTML::FormHandler::Field';

=head1 SYNOPSIS

This field is not currently used. Placeholder for possible future
atomic radio buttons.

  <label class="label" for="[% field.name %]">[% field.label</label>
  <input name="[% field.name %]" type="radio"
    value="[% field.radio_value %]"
    [% IF field.fif == field.radio_value %]
       select="selected"
    [% END %]
   />


=head2 radio_value

See synopsis. Sets the value used in the radio button.

=cut

has 'radio_value' => ( is => 'rw', default => 1 );

has '+widget' => ( default => 'radio' );

__PACKAGE__->meta->make_immutable;
use namespace::autoclean;
1;
