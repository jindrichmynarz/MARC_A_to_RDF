PREFIX void:    <http://rdfs.org/ns/void#>

INSERT {
  GRAPH ?metadataGraph {
    ?graph void:distinctSubjects ?distinctSubjects ;
      void:properties ?properties ;
      void:distinctObjects ?distinctObjects ;
      void:triples ?triples .
  }
}
WHERE {
  {
    SELECT (COUNT(DISTINCT ?s) AS ?distinctSubjects)
           (COUNT(DISTINCT ?p) AS ?properties)
           (COUNT(DISTINCT ?o) AS ?distinctObjects)
           (COUNT(*) AS ?triples)
    WHERE {
      GRAPH ?graph {
        ?s ?p ?o .
      }
    }
  }
  BIND (IRI(CONCAT(STR(?graph), "/metadata")) AS ?metadataGraph) 
}
