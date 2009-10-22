#!/usr/bin/perl

BEGIN {
    if (-d '.git') {
        unshift @INC, 'lib';
    }
}
use App::Hamaki;

App::Hamaki->new_with_options()->run();