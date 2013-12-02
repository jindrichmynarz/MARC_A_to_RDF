PREFIX skos: <http://www.w3.org/2004/02/skos/core#>

WITH ?graph
INSERT {
  ?outConcept ?outProperty ?inConcept . 
}
WHERE {
  VALUES (?inProperty             ?outProperty) {
         (skos:broader            skos:narrower)
         (skos:broaderTransitive  skos:narrowerTransitive)
         (skos:narrower           skos:broader)
         (skos:narrowerTransitive skos:broaderTransitive)
         (skos:related            skos:related)
  }
  ?inConcept a skos:Concept ;
    ?inProperty ?outConcept .
  ?outConcept a skos:Concept .
}
