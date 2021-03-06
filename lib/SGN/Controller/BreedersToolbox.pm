
package SGN::Controller::BreedersToolbox;

use Moose;

use URI::FromHash 'uri';
BEGIN { extends 'Catalyst::Controller'; }


sub make_cross_form :Path("/stock/cross/new") :Args(0) { 
    my ($self, $c) = @_;
    $c->stash->{template} = '/breeders_toolbox/new_cross.mas';
    if ($c->user()) { 
      my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
      # get projects
      my @rows = $schema->resultset('Project::Project')->all();
      my @projects = ();
      foreach my $row (@rows) { 
	push @projects, [ $row->project_id, $row->name, $row->description ];
      }
      $c->stash->{project_list} = \@projects;
      @rows = $schema->resultset('NaturalDiversity::NdGeolocation')->all();
      my @locations = ();
      foreach my $row (@rows) {
	push @locations,  [ $row->nd_geolocation_id,$row->description ];
      }
      $c->stash->{locations} = \@locations;

    }
    else {
      $c->res->redirect( uri( path => '/solpeople/login.pl', query => { goto_url => $c->req->uri->path_query } ) );
      return;
    }
}


sub make_cross :Path("/stock/cross/generate") :Args(0) { 
    my ($self, $c) = @_;
    $c->stash->{template} = '/breeders_toolbox/progeny_from_crosses.mas';
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $cross_name = $c->req->param('cross_name');
    $c->stash->{cross_name} = $cross_name;
    my $trial_id = $c->req->param('trial_id');
    $c->stash->{trial_id} = $trial_id;
    #my $location = $c->req->param('location_id');
    my $maternal = $c->req->param('maternal');
    my $paternal = $c->req->param('paternal');
    my $prefix = $c->req->param('prefix');
    my $suffix = $c->req->param('suffix');
    my $progeny_number = $c->req->param('progeny_number');
    my $visible_to_role = $c->req->param('visible_to_role');
    
    if (! $c->user()) { # redirect
	$c->res->redirect( uri( path => '/solpeople/login.pl', query => { goto_url => $c->req->uri->path_query } ) );
	return;
    }


    #check that progeny number is an integer less than maximum allowed
    my $maximum_progeny_number = 1000;
    if ((! $progeny_number =~ m/^\d+$/) or ($progeny_number > $maximum_progeny_number)){
      #redirect to error page?
      return;
    }

    #check that parent names are not blank
    if ($maternal eq "" or $paternal eq "") {
      return;
    }

    #check that parents exist in the database
    if (! $schema->resultset("Stock::Stock")->find({name=>$maternal,})){
      return;
    }
    if (! $schema->resultset("Stock::Stock")->find({name=>$paternal,})){
      return;
    }

    #check that cross name does not already exist
    if ($schema->resultset("Stock::Stock")->find({name=>$cross_name})){
      return;
    }

    #check that progeny do not already exist
    if ($schema->resultset("Stock::Stock")->find({name=>$prefix.$cross_name.$suffix."-1",})){
      return;
    }

    my $organism = $schema->resultset("Organism::Organism")->find_or_create(
    {
	genus   => 'Manihot',
	species => 'Manihot esculenta',
    } );
    my $organism_id = $organism->organism_id();

    my $accession_cvterm = $schema->resultset("Cv::Cvterm")->create_with(
      { name   => 'accession',
      cv     => 'stock type',
      db     => 'null',
      dbxref => 'accession',
    });

#    my $population_cvterm = $schema->resultset("Cv::Cvterm")->create_with(
#      { name   => 'member',
#      cv     => 'stock type',
#      db     => 'null',
#      dbxref => 'member',
#    });

    my $population_cvterm = $schema->resultset("Cv::Cvterm")->find(
      { name   => 'population',
    });

#    my $cross_cvterm = $schema->resultset("Cv::Cvterm")->create_with(
#    { name   => 'cross',
#      cv     => 'stock relationship',
#      db     => 'null',
#      dbxref => 'cross',
#    });

    my $female_parent_stock = $schema->resultset("Stock::Stock")->find(
            { name       => $maternal,
            } );

    my $male_parent_stock = $schema->resultset("Stock::Stock")->find(
            { name       => $paternal,
            } );

    my $population_stock = $schema->resultset("Stock::Stock")->find_or_create(
            { organism_id => $organism_id,
	      name       => $cross_name,
	      uniquename => $cross_name,
	      type_id => $population_cvterm->cvterm_id,
            } );
      my $female_parent = $schema->resultset("Cv::Cvterm")->create_with(
    { name   => 'female_parent',
      cv     => 'stock relationship',
      db     => 'null',
      dbxref => 'female_parent',
    });

      my $male_parent = $schema->resultset("Cv::Cvterm")->create_with(
    { name   => 'male_parent',
      cv     => 'stock relationship',
      db     => 'null',
      dbxref => 'male_parent',
    });

      my $population_members = $schema->resultset("Cv::Cvterm")->create_with(
    { name   => 'cross_name',
      cv     => 'stock relationship',
      db     => 'null',
      dbxref => 'cross_name',
    });

      my $visible_to_role_cvterm = $schema->resultset("Cv::Cvterm")->create_with(
    { name   => 'visible_to_role',
      cv => 'local',
      db => 'null',
    });

    my $increment = 1;
    while ($increment < $progeny_number + 1) {
	my $stock_name = $prefix.$cross_name."-".$increment.$suffix;
      my $accession_stock = $schema->resultset("Stock::Stock")->create(
            { organism_id => $organism_id,
              name       => $stock_name,
              uniquename => $stock_name,
              type_id     => $accession_cvterm->cvterm_id,
            } );
      $accession_stock->find_or_create_related('stock_relationship_objects', {
		type_id => $female_parent->cvterm_id(),
		object_id => $accession_stock->stock_id(),
		subject_id => $female_parent_stock->stock_id(),
	 					  } );
      $accession_stock->find_or_create_related('stock_relationship_objects', {
		type_id => $male_parent->cvterm_id(),
		object_id => $accession_stock->stock_id(),
		subject_id => $male_parent_stock->stock_id(),
	 					  } );
      $accession_stock->find_or_create_related('stock_relationship_objects', {
		type_id => $population_members->cvterm_id(),
		object_id => $accession_stock->stock_id(),
		subject_id => $population_stock->stock_id(),
	 					  } );
      if ($visible_to_role ne "") {
	my $accession_stock_prop = $schema->resultset("Stock::Stockprop")->find_or_create(
	       { type_id =>$visible_to_role_cvterm->cvterm_id(),
		 value => $visible_to_role,
		 stock_id => $accession_stock->stock_id()
		 });
      }
      $increment++;

    }
    if ($@) { 
    }
}



    
sub breeder_home :Path("/breeders/home") Args(0) { 
    my ($self , $c) = @_;
    if ($c->user()) { 
	
	my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

	# get projects

	my @rows = $schema->resultset('Project::Project')->all();

	my @projects = ();
	foreach my $row (@rows) { 
	    push @projects, [ $row->project_id, $row->name, $row->description ];

	}

	$c->stash->{projects} = \@projects;

	#get roles

	my @roles = $c->user->roles();
	$c->stash->{roles}=\@roles;

	#get crosses


	my $population_cvterm = $schema->resultset("Cv::Cvterm")->find(
								       { name   => 'cross',
								       });

	my @cross_population_stocks = $schema->resultset("Stock::Stock")->search(
            { type_id => $population_cvterm->cvterm_id,
            } );

	my @cross_populations = ();

	foreach my $cross_pop (@cross_population_stocks) {
	  push @cross_populations, [$cross_pop->name,$cross_pop->stock_id];
	}


	$c->stash->{cross_populations} = \@cross_populations;

	my $stockrel = $schema->resultset("Cv::Cvterm")->create_with(
	 { name   => 'cross',
	   cv     => 'stock relationship',
	   db     => 'null',
	   dbxref => 'cross',
	 });



	#my $stockrel_type_id = $schema->resultset('Cv::Cvterm')->search( { 'name'=>'cross' })->first->cvterm_id;

	@rows = $schema->resultset('Stock::StockRelationship')->search( {type_id => $stockrel->cvterm_id });

	my @stockrelationships = ();

	foreach my $row (@rows) {
	  push @stockrelationships, [$row->type_id];
	}

	push @stockrelationships, ["example"];
	
	$c->stash->{stockrelationships} = \@stockrelationships;

	# get locations

	@rows = $schema->resultset('NaturalDiversity::NdGeolocation')->all();

	my $type_id = $schema->resultset('Cv::Cvterm')->search( { 'name'=>'plot' })->first->cvterm_id;

	my @locations = ();
	foreach my $row (@rows) { 

	    
	    my $plot_count = "SELECT count(*) from stock join cvterm on(type_id=cvterm_id) join nd_experiment_stock using(stock_id) join nd_experiment using(nd_experiment_id)   where cvterm.name='plot' and nd_geolocation_id=?"; # and sp_person_id=?";
	    my $sh = $c->dbc->dbh->prepare($plot_count);
	    $sh->execute($row->nd_geolocation_id); #, $c->user->get_object->get_sp_person_id);
	    
	    my ($count) = $sh->fetchrow_array();

	    print STDERR "PLOTS: $count\n";
	    
	    #if ($count > 0) { 

		push @locations,  [ $row->nd_geolocation_id, 
				    $row->description,
				    $row->latitude,
				    $row->longitude,
				    $row->altitude,
				    $count, # number of experiments TBD
				
		];
	#}
	}

	$c->stash->{locations} = \@locations;
	$c->stash->{template} = '/breeders_toolbox/home.mas';
    }
    else {
	# redirect to login page
	$c->res->redirect( uri( path => '/solpeople/login.pl', query => { goto_url => $c->req->uri->path_query } ) );
    }
}


sub breeder_search : Path('/breeder_search/') :Args(0) { 
    my ($self, $c) = @_;
    
    $c->stash->{template} = '/breeders_toolbox/breeder_search.mas';

}

sub trial_info : Path('/breeders_toolbox/trial') Args(1) { 
    my $self = shift;
    my $c = shift;

    my $trial_id = shift;
    
    if (!$c->user()) { 
	$c->stash->{template} = '/generic_message.mas';
	$c->stash->{message}  = 'You must be logged in to access this page.';
	return;
    }
    my $dbh = $c->dbc->dbh();
    
    my $h = $dbh->prepare("SELECT project.name FROM project WHERE project_id=?");
    $h->execute($trial_id);

    my ($name) = $h->fetchrow_array();

    $c->stash->{trial_name} = $name;

    $h = $dbh->prepare("SELECT distinct(nd_geolocation.nd_geolocation_id), nd_geolocation.description, count(*) FROM nd_geolocation JOIN nd_experiment USING(nd_geolocation_id) JOIN nd_experiment_project USING (nd_experiment_id) JOIN project USING (project_id) WHERE project_id=? GROUP BY nd_geolocation_id, nd_geolocation.description");
    $h->execute($trial_id);

    my @location_data = ();
    while (my ($id, $desc, $count) = $h->fetchrow_array()) { 
	push @location_data, [$id, $desc, $count];
    }		       

    $c->stash->{location_data} = \@location_data;

    $h = $dbh->prepare("SELECT distinct(cvterm.name), count(*) FROM cvterm JOIN phenotype ON (cvterm_id=cvalue_id) JOIN nd_experiment_phenotype USING(phenotype_id) JOIN nd_experiment_project USING(nd_experiment_id) WHERE project_id=? GROUP BY cvterm.name");

    $h->execute($trial_id);

    my @phenotype_data;
    while (my ($trait, $count) = $h->fetchrow_array()) { 
	push @phenotype_data, [$trait, $count];
    }
    $c->stash->{phenotype_data} = \@phenotype_data;

    $h = $dbh->prepare("SELECT distinct(projectprop.value) FROM projectprop WHERE project_id=? AND type_id=(SELECT cvterm_id FROM cvterm WHERE name='project year')");
    $h->execute($trial_id);

    my @years;
    while (my ($year) = $h->fetchrow_array()) { 
	push @years, $year;
    }
    

    $c->stash->{years} = \@years;

    $c->stash->{plot_data} = [];

    $c->stash->{template} = '/breeders_toolbox/trial.mas';
}


1;
