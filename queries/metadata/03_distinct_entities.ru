PREFIX void:    <http://rdfs.org/ns/void#>

INSERT {
  GRAPH ?metadataGraph {
    ?graph void:entities ?entities .
  }
}
WHERE {
  {
    SELECT (COUNT(DISTINCT ?entity) AS ?entities)
    WHERE {
      GRAPH ?graph {
        ?entity ?p ?o .
        FILTER (!isBlank(?entity))
      }
    }
  }
  BIND (IRI(CONCAT(STR(?graph), "/metadata")) AS ?metadataGraph) 
}
