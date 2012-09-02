package Lunar::GitHUB::api::ReceiveHook;
use Dancer ':syntax';
use Mail::Sendmail;
use LWP;
use DateTime::Format::Strptime;
use DateTime::Format::ISO8601;

use Data::Dumper;

prefix '/api';

post '/receivehook/:apikey' => sub {
  if (config->{api_key} ne params->{apikey}) {
    return "Invalid API key";
  }

  if (not defined params->{'payload'}) {
    status '415';
    warning "No payload!";
    return "Give me COOOOOKIES!";
  }

  my $data = from_json(params->{'payload'});

  # For now we only want 'refs/heads/master', disregard all other branches
  warning "Skipping mail for ref: " . $data->{'ref'} and return unless ($data->{'ref'} eq 'refs/heads/master');

  # Name of the repository
  my $repo = $data->{'repository'}->{'name'};
  # Owner of repository, either private or an organization
  my $repo_owner = $data->{'repository'}->{'owner'}->{'name'};

  foreach my $commit (@{$data->{'commits'}}) {
    my $patch_github = get_patch("https://api.github.com/repos/${repo_owner}/${repo}/commits/" . $commit->{'id'});

    if (not defined $patch_github) {
      warning "Failed to get a patch for " . $commit->{'id'};
      next;
    }

    $commit->{patch} = $patch_github;

    my $subject = get_subject_line($commit->{'message'});
    my $message = format_message(\$commit);
    if (not defined $subject or not defined $message) {
      warning "Failed to generate a commit subject line or message\n";
      next;
    }
    my $from = get_name_email($commit->{'committer'});

    # TODO: Store commit in SQLite

    # repo, from, commit_date, subject, message
    send_email($repo, $from, $commit->{'timestamp'}, $subject, $message);
  }
};

sub get_patch {
  my $github_url = shift;

  my $ua = new LWP::UserAgent;
  $ua->agent("Lunar-GitHUB/$Lunar::GitHUB::VERSION");
  my $req = HTTP::Request->new(GET => $github_url);
  my $res = $ua->request($req);

  if ($res->is_success and $res->content_type eq "application/json") {
    return from_json($res->content);
  }

  warning "Failed to get patch from github for $github_url";
  return;
}

sub get_rfc2822_date {
  my $date = shift;

  my $strp = DateTime::Format::Strptime->new(pattern => '%a, %d %b %Y %T %z');
  my $dt = DateTime::Format::ISO8601->parse_datetime($date);

  return $strp->format_datetime($dt);
}

sub get_subject_line {
  my $commit_msg = shift;
  return (split(/\n/, $commit_msg))[0] if defined $commit_msg || return "";
}

sub get_name_email {
  my $info = shift;
  return $info->{'name'} . " <" . $info->{'email'} . ">";
}

sub format_message {
  my $commit = shift;

  # Build message
  my $message = "commit " . $$commit->{'id'} . "\n";
  $message .= "Author: " . get_name_email($$commit->{'author'}) . "\n";
  $message .= "Date: " . get_rfc2822_date($$commit->{'timestamp'}) . "\n";
  $message .= "URL: " . $$commit->{'url'} . "\n\n";
  $message .= $$commit->{'message'} . "\n---\n";

  # List files with additions/deletions
  my $nr_files_changed = scalar(@{$$commit->{'patch'}->{'files'}});
  my ($counter, $rcounter, $acounter, $str_len) = 0;
  my @changes;

  foreach my $file (@{$$commit->{'patch'}->{'files'}}) {
    if ($file->{'changes'} > 0) {
      push @changes, {filename => $file->{'filename'}, changes => "+" . $file->{'additions'} . "/-" . $file->{'deletions'}};
      if ($file->{'status'} eq 'added') {
        $acounter++;
      } elsif ($file->{'status'} eq 'removed') {
        $rcounter++;
      }
    } else {   #for now we assume this is a renamed file heaven forbid if I'm wrong ;)
      push @changes, {filename => $$commit->{'removed'}[$counter+$rcounter] . " -> " . $$commit->{'added'}[$counter+$acounter]};
      $counter++;
    }
    # Find longest string for formatting
    $str_len = length($changes[-1]{'filename'}) if length($changes[-1]{'filename'}) > $str_len;
  }

  # Formatted output
  for my $ref (@changes) {
    if ($ref->{'changes'}) {
      $message .= sprintf("  %-*s | %-10s\n", $str_len, $ref->{'filename'}, $ref->{'changes'});
    } else {
      $message .= sprintf("  %-*s\n", $str_len, $ref->{'filename'});
    }
  }

  # Stats
  my $additions = $$commit->{'patch'}->{'stats'}->{'additions'};
  my $deletions = $$commit->{'patch'}->{'stats'}->{'deletions'};
  $message .= "  $nr_files_changed";
  $message .= $nr_files_changed > 1 ? " files changed" : " file changed";
  $message .= ", " . $additions . ($additions > 1 ? " insertions(+)" : " insertion(+)") if $additions > 0;
  $message .= ", " . $deletions . ($deletions > 1 ? " deletions(-)" : " deletion(-)") if $deletions > 0;
  $message .="\n\n";

  # Diffs
  foreach my $file (@{$$commit->{'patch'}->{'files'}}) {
    # Do not show a diff for non-modified files (might just be renamed)
    if ($file->{'changes'} > 0) {
      # Header
      if ($file->{'status'} eq 'modified') {
        $message .= "--- a/" . $file->{'filename'} . "\n+++ b/" . $file->{'filename'} . "\n";
      } elsif ($file->{'status'} eq 'added') {
        $message .= "--- /dev/null" . "\n+++ b/" . $file->{'filename'} . "\n";
      } elsif ($file->{'status'} eq 'removed') {
        $message .= "--- a/" . $file->{'filename'} . "\n+++ /dev/null\n";
      }
      $message .= $file->{'patch'} . "\n";
    }
  }
  return $message . "\n";
}

# repo, from, commit_date, subject, message
sub send_email {
  my ($repo, $from, $date, $subject, $message) = @_;

  my %mail = (
    smtp => config->{smtp},
    To => config->{mailing_list},
    From => $from,
    Subject => "<$repo> $subject",
    Date => get_rfc2822_date($date),
    Message => $message
  );

  # Only send mail in production mode
  if (setting('environment') eq 'production') {
    sendmail(%mail) or warning "Failed to send mail";
  } else {
    debug "Mail: " . Dumper(%mail);
    debug "Sending mail to " . config->{mailing_list};
  }
}
