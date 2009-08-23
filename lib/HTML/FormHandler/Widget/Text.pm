package HTML::FormHandler::Widget::Text;

use Moose::Role;
with 'HTML::FormHandler::Widget::Field';

sub render
{
   my ( $self, $result ) = @_;

   $result ||= $self->result;
   my $output = '<input type="text" name="';
   $output .= $self->html_name . '"';
   $output .= ' id="' . $self->id . '"';
   $output .= ' size="' . $self->size . '"' if $self->size;
   $output .= ' maxlength="' . $self->maxlength . '"' if $self->maxlength;
   $output .= ' value="' . $self->fif($result) . '" />';
   return $self->render_field($result, $output);
}

no Moose::Role;
1;
