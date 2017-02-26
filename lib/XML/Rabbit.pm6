unit module XML::Rabbit;
no precompilation;

our role XML::Rabbit::Node {
    use XML::XPath;
    use XML;

    has $.context is rw;
    has $.xpath is rw;

    submethod TWEAK(:$file) {
        if $file {
            $!xpath   = XML::XPath.new(:$file);
            $!context = $!xpath.document;
        }
    }
}

my role XmlRabbitAttribute {
    has $.xpath-expression is rw;
}

my class X::Usage is Exception {
    has Str $.message is rw;
}

my class X::XmlRabbitNodeException is Exception {
    has Str $.message is rw;
}

my role XmlRabbitAttributeHOW {
    use XML;
    method compose(Mu \type) {
        for type.^attributes.grep(XmlRabbitAttribute) -> $attr {
            my $method-name = $attr.name.substr(2);
            # exists key $attr.base-name in method_table
            if type.^method_table{$method-name}:exists {
                X::Usage.new(
                    message =>"A method '{$method-name}' already exists, can't create lazy accessor '\$.{$method-name}'"
                ).throw();
            }
            for type.^roles_to_compose -> $r {
                if $r.new.^method_table{$method-name}:exists {
                    X::Usage.new(
                        message =>"A method '{$method-name}' is provided by role '{$r.WHAT.^name}', can't create lazy accessor '\$.{$method-name}'"
                    ).throw();
                }
            }

            type.^add_method(
                $method-name,
                method (Mu:D:) {
                    my $val = $attr.get_value( self );
                    unless $val.defined {
                        unless self.context.defined {
                            X::XmlRabbitNodeException.new(message => "This Class doesn't have an XML Context.").throw();
                        }
                        unless self.xpath.defined {
                            X::XmlRabbitNodeException.new(message => "This Class doesn't have an XML Xpath Expression").throw();
                        }
                        $val = self.xpath.find($attr.xpath-expression, start => self.context);
                        $val = $val ~~ XML::Node ?? join '', $val.contents>>.text !! $val;
                        $attr.set_value( self, $val );
                    }
                    return $val;
                });
        }
        callsame;
    }
}

multi trait_mod:<is>(Attribute:D $attr, :$xpath! ) is export {
    my $class := $attr.package;
    $attr does XmlRabbitAttribute;
    $attr.xpath-expression = $xpath;

    unless $class.HOW ~~ XmlRabbitAttributeHOW {
        $class.HOW does XmlRabbitAttributeHOW
    }
}
