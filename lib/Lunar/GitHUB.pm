package Lunar::GitHUB;
use Dancer ':syntax';

our $VERSION = '0.8';

use Lunar::GitHUB::api::receivehook;

prefix undef;

get '/' => sub {
  redirect "http://lunar-linux.org/";
};

true;
