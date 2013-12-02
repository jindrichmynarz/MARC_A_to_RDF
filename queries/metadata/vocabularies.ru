PREFIX void:    <http://rdfs.org/ns/void#>

INSERT {
  GRAPH ?metadataGraph {
    ?graph void:vocabulary ?vocabulary .
  }
}
WHERE {
  {
    SELECT DISTINCT ?vocabulary
    WHERE {
      {
        SELECT DISTINCT ?tbox
        WHERE {
          GRAPH ?graph {
            {
              [] a ?tbox .
            } UNION {
              [] ?tbox [] .
            }
          }
        }
      }
      FILTER (isIRI(?tbox))
      BIND (IRI(REPLACE(STR(?tbox), "^(.+[\\/#])[^\\/#]+$", "$1")) AS ?vocabulary)
    }
  }
  BIND (IRI(CONCAT(STR(?graph), "/metadata")) AS ?metadataGraph) 
}
