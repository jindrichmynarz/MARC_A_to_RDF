PREFIX dcterms: <http://purl.org/dc/terms/>
PREFIX void:    <http://rdfs.org/ns/void#>
PREFIX xsd:     <http://www.w3.org/2001/XMLSchema#>

INSERT {
  GRAPH ?metadataGraph {
    ?graph a void:Dataset ;
      dcterms:lastModified ?now ;
      void:vocabulary ?vocabulary ;
      void:classes ?classes ;
      void:entities ?entities ;
      void:distinctSubjects ?distinctSubjects ;
      void:properties ?properties ;
      void:distinctObjects ?distinctObjects ;
      void:triples ?triples .
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
  {
    SELECT (COUNT(DISTINCT ?entity) AS ?entities)
    WHERE {
      GRAPH ?graph {
        ?entity ?p ?o .
        FILTER (!isBlank(?entity))
      }
    }
  }
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
  BIND (xsd:dateTime(NOW()) AS ?now)
  BIND (IRI(CONCAT(STR(?graph), "/metadata")) AS ?metadataGraph) 
}
