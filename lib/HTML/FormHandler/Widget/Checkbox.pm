package HTML::FormHandler::Widget::Checkbox;

use Moose::Role;
with 'HTML::FormHandler::Widget::Field';

sub render
{
   my ( $self, $result ) = @_;

   $result ||= $self->result;
   my $fif = $result->fif($result);
   my $output = '<input type="checkbox" name="';
   $output .=
      $self->html_name . '" id="' . $self->id . '" value="' . $self->checkbox_value . '"';
   $output .= ' checked="checked"' if $fif eq $self->checkbox_value;
   $output .= ' />';
   return $self->render_field($result, $output);
}

1;
