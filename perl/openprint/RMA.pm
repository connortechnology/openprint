use strict;
package openprint::RMA;

use vars qw( $debug %fields %transforms %defaults );

%fields = (
    id	=>	'id',
    company_id	=>	'company_id',
    user_id		=>	'user_id',
    project_id	=>	'project_id',
    order_id	=>	'order_id',
    type		=>	'type',
    created_on	=>	'created_on',
    description	=>	'description',
    comments	=>	'comments',
    rmanumber	=>	'rmanumber',
    approved	=>	'approved',
);

%transforms = (
);

%defaults = (
);

1;
__END__
