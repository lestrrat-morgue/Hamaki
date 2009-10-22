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
requires 'Tatsumaki::Application';
requires 'Tatsumaki::Error';
requires 'Tatsumaki::HTTPClient';
requires 'Tatsumaki::MessageQueue';
requires 'Tatsumaki::Middleware::BlockingFallback';
requires 'Tatsumaki::Server';
requires 'Tatsumaki';
requires 'Try::Tiny';
requires 'namespace::clean';

WriteAll;

