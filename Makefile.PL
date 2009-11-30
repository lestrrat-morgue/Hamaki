use inc::Module::Install;

name('Hamaki');

requires 'AnyEvent::HTTP';
requires 'Encode';
requires 'HTML::Entities';
requires 'MIME::Base64';
requires 'Moose';
requires 'MooseX::Getopt';
requires 'MooseX::SimpleConfig';
requires 'Plack::Middleware::Static';
requires 'Tatsumaki' => '0.1003';
requires 'Try::Tiny';
requires 'namespace::clean';

WriteAll;

