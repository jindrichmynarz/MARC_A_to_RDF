PREFIX dcterms: <http://purl.org/dc/terms/>
PREFIX void:    <http://rdfs.org/ns/void#>
PREFIX xsd:     <http://www.w3.org/2001/XMLSchema#>

INSERT {
  GRAPH ?metadataGraph {
    ?graph a void:Dataset ;
      dcterms:lastModified ?now .
  }
}
WHERE {
  BIND (xsd:dateTime(NOW()) AS ?now)
  BIND (IRI(CONCAT(STR(?graph), "/metadata")) AS ?metadataGraph) 
}
