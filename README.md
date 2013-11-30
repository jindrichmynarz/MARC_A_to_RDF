# MARC for Authority Records to RDF

XSL transformation for converting data represented with [MARC 21 for Authority Records](http://loc.gov/marc/authority/) and serialized in [MARC XML](http://www.loc.gov/standards/marcxml/) to [RDF](http://www.w3.org/RDF/). The resulting RDF uses primarily [Simple Knowledge Organization System](http://www.w3.org/TR/skos-primer/) and [MADS/RDF](http://www.loc.gov/standards/mads/rdf/). The XSLT is accompanied with scripted tasks for driving the transformation, loading data into an RDF store and executing SPARQL queries for enriching the data.

The transformation was developed for an [LOD2 Publink](http://lod2.eu/Article/Publink.html) project with the [National Library of Israel](http://web.nli.org.il/sites/nli/english). 

## Steps

Steps of the transformation are implemented as Rake tasks. Use `rake -T` to list all available tasks.

1. `rake xslt[path/to/marc-21-a.xml]` to execute the XSL transformation from MARC XML to RDF/XML (file `tmp/output.rdf`).
2. `rake fuseki:load` to load the created RDF in Jena TDB.
3. `rake fuseki:start` to start a SPARQL endpoint for the loaded data.
4. `rake sparql:enrich` to issue several SPARQL Update requests that will enrich the processed data.
5. `rake fuseki:stop` to stop the SPARQL endpoint.
6. `rake fuseki:dump` to export the transformed dataset into [NQuads](http://www.w3.org/TR/n-quads/) file (`tmp/dump.nq`). 
7. `rake fuseki:purge` to clear all Jena TDB files.

## Dependencies

* [Fuseki](http://jena.apache.org/documentation/serving_data/)
* [Jena](http://jena.apache.org/): uses Jena TDB as database 
* [Rake](http://rake.rubyforge.org/): works with Ruby version 1.8.7 or newer
* [Saxon](http://saxon.sourceforge.net/): version 9.x, can be replaced by any XSLT 2.0 processor
