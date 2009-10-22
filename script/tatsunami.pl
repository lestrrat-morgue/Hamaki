#!/usr/bin/perl

BEGIN {
    if (-d '.git') {
        unshift @INC, 'lib';
    }
}
use App::Tatsunami;

App::Tatsunami->new_with_options()->run();