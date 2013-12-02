PREFIX void:    <http://rdfs.org/ns/void#>

INSERT {
  GRAPH ?metadataGraph {
    ?graph void:classes ?classes . 
  }
}
WHERE {
  {
    SELECT (COUNT(DISTINCT ?class) AS ?classes)
    WHERE {
      GRAPH ?graph {
        [] a ?class .
      }
    }
  }
  BIND (IRI(CONCAT(STR(?graph), "/metadata")) AS ?metadataGraph) 
}
