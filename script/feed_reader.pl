use strict;
use warnings;
use Pig;
use Pig::Service::FeedReader;

my $pig = Pig->new(
    service => Pig::Service::FeedReader->new( 
        interval => 5,         # 5分毎にチェック
        bot_name => 'feed',
        channels => {
            '#fse' => {
                feeds => [
                    { uri => 'http://www.douzemille.net/labs/urlstack/rss.cgi' },
                ],
            }
        },
    ),
    config => { port => 16668 },
);
$pig->run;

