package HTML::FormHandler::Fields;

use Moose::Role;
use Carp;
use UNIVERSAL::require;
use Class::Inspector;

=head1 NAME

HTML::FormHandler::Fields - role to build field array

=head1 SYNOPSIS

These are internal methods to build the field array. Probably
not useful to users. 

=head2 fields

The field definitions as built from the field_list and the 'has_field'
declarations. This is a MooseX::AttributeHelpers::Collection::Array, 
and provides clear_fields, add_field, remove_last_field, num_fields,
has_fields, and set_field_at methods.

=cut

has 'fields' => (
   metaclass  => 'Collection::Array',
   isa        => 'ArrayRef[HTML::FormHandler::Field]',
   is         => 'rw',
   default    => sub { [] },
   auto_deref => 1,
   provides   => {
      clear => 'clear_fields',
      push  => 'add_field',
      pop   => 'remove_last_field',
      count => 'num_fields',
      empty => 'has_fields',
      set   => 'set_field_at',
   }
);

=head2 build_fields

This parses the field lists and creates the individual
field objects.  It calls the make_field() method for each field.
This is called by the BUILD method. Users don't need to call this.

=cut

sub build_fields
{
   my $self = shift;

   my $meta_flist = $self->_build_meta_field_list;
   $self->_build_fields( $meta_flist, 0 ) if $meta_flist; 
   if( $self->can('field_list') )
   {
      my $flist = $self->field_list;
      $self->_build_fields( $flist->{'required'}, 1 ) if $flist->{'required'}; 
      $self->_build_fields( $flist->{'optional'}, 0 ) if $flist->{'optional'};
      $self->_build_fields( $flist->{'fields'}, 0 )   if $flist->{'fields'};
      $self->_build_fields( $flist->{'auto_required'}, 1, 'auto' ) 
                                                 if $flist->{'auto_required'};
      $self->_build_fields( $flist->{'auto_optional'}, 0, 'auto' ) 
                                                 if $flist->{'auto_optional'};
   }
   return unless $self->has_fields;
   # get highest order number
   my $order = 0;
   foreach my $field ( $self->fields)
   {
      $order++ if $field->order > $order;
   }
   $order++;
   # number all unordered fields
   my @expand_fields;
   foreach my $field ( $self->fields )
   {
      $field->order( $order ) unless $field->order;
      $order++;
      # collect child references in parent field
      push @expand_fields, $field if $field->name =~ /\./;
   }
   @expand_fields = sort { $a->name cmp $b->name } @expand_fields;
   foreach my $field ( @expand_fields )
   {
      my @names = split /\./, $field->name;
      my $simple_name = pop @names;
      my $parent_name = pop @names;
      my $parent = $self->field($parent_name);
      next unless $parent;
      $field->parent($parent);
      $field->name( $simple_name ); 
      $parent->add_field($field);
   }

}

sub _build_meta_field_list
{
   my $self = shift;
   my @field_list;
   foreach my $sc ( reverse $self->meta->linearized_isa )
   {
      my $meta = $sc->meta;
      foreach my $role ( $meta->calculate_all_roles )
      {
         if ( $role->can('field_list') && $role->has_field_list )
         {
            push @field_list, @{$role->field_list};
         }
      }
      if ( $meta->can('field_list') && $meta->has_field_list )
      {
         push @field_list, @{$meta->field_list};
      }
   }
   return \@field_list if scalar @field_list;
}

sub _build_fields
{
   my ( $self, $fields, $required, $auto ) = @_;

   warn "HFH: build_fields for ", $self->name, ", ", ref($self), "\n" if
      $self->form && $self->form->verbose;
   return unless $fields;
   my $field;
   my $name;
   my $type;
   if ($auto)    # an auto array of fields
   {
      foreach $name (@$fields)
      {
         $type = $self->guess_field_type($name);
         croak "Could not guess field type for field '$name'" unless $type;
         $self->_set_field( $name, $type, $required );
      }
   }
   elsif ( ref($fields) eq 'ARRAY' )    # an array of fields
   {
      while (@$fields)
      {
         $name = shift @$fields;
         $type = shift @$fields;
         $self->_set_field( $name, $type, $required );
      }
   }
   else                                 # a hashref of fields
   {
      while ( ( $name, $type ) = each %$fields )
      {
         $self->_set_field( $name, $type, $required );
      }
   }
   return;
}

sub _set_field
{
   my ( $self, $name, $type, $required ) = @_;

   my $field = $self->make_field( $name, $type );
   return unless $field;
   $field->required($required) unless ( $field->required == 1 );
   my $index = $self->field_index($field->full_name);
   if( defined $index )
      { $self->set_field_at($index, $field); }
   else
      { $self->add_field($field); }
}

=head2 make_field

    $field = $form->make_field( $name, $type );

Maps the field type to a field class, creates a field object and
and returns it.

The "$name" parameter is the field's name (e.g. first_name, age).

The second parameter is either a scalar which is the field's type
string, or a hashref with a 'type' key containing the field's type.

=cut

sub make_field
{
   my ( $self, $name, $attr ) = @_;

   $attr = { type => $attr } unless ref $attr eq 'HASH';
   my $type = $attr->{type} ||= 'Text';

   # TODO what about fields with fields? namespace from where?
   my $class =
        $type =~ s/^\+//
      ? $self->field_name_space
         ? $self->field_name_space . "::" . $type
         : $type
      : 'HTML::FormHandler::Field::' . $type;
      
   $class->require 
      or die "Could not load field class '$type' $class for field '$name'"
      if !Class::Inspector->loaded($class);

   # Add field name and reference to form 
   $attr->{name} = $name;
   $attr->{form} = $self->form if $self->form;
   $attr->{parent} = $self unless ($self->form && $self == $self->form);
   my $field = $class->new( %{$attr} );
   return $field;
}

=head2 field_index

Convenience function for use with 'set_field_at'.

=cut 

sub field_index
{
   my ( $self, $full_name ) = @_;
   my $index = 0;
   for my $field ( $self->fields )
   {
      return $index if $field->full_name eq $full_name;
      $index++;
   }
   return;
}

=head2 field

=cut

sub field
{
   my ( $self, $name, $no_die ) = @_;

   for my $field ( $self->fields )
   {
      return $field if ($field->full_name eq $name || $field->name eq $name);
   }
   return if $no_die;
   croak "Field '$name' not found in '$self'";
}

=head2 sorted_fields

Calls fields and returns them in sorted order by their "order"
value. Non-sorted fields are retrieved with 'fields'. 

=cut

sub sorted_fields
{
   my $self = shift;

   my @fields = sort { $a->order <=> $b->order } $self->fields;
   return wantarray ? @fields : \@fields;
}

=head2 fields_validate

=cut

sub fields_validate
{
   my $self = shift;
   # validate all fields
   foreach my $field ( $self->fields )
   {
      next if $field->clear;    # Skip validation
      # parent fields will call validation for children
      next if $field->parent && $field->parent != $self;
      # Validate each field and "inflate" input -> value.
      $field->validate_field;  # this calls the field's 'validate' routine
      next unless $field->has_value && defined $field->value; 
      # these methods have access to the inflated values
      $field->_validate($field); # will execute a form-field validation routine
   }
}

no Moose::Role;
1;
