package Lunar::GitHUB;
use Dancer ':syntax';

our $VERSION = '0.9.1';

use Lunar::GitHUB::api::ReceiveHook;

prefix undef;

get '/' => sub {
  redirect "http://lunar-linux.org/";
};

true;
