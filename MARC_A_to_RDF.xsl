<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:f="http://opendata.cz/xslt/functions#"
    xmlns:fn="http://www.w3.org/2005/xpath-functions"
    xmlns:marc="http://www.loc.gov/MARC21/slim"
    
    xmlns:dcterms="http://purl.org/dc/terms/"
    xmlns:mads="http://www.loc.gov/mads/rdf/v1#"
    xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    xmlns:schema="http://schema.org/"
    xmlns:skos="http://www.w3.org/2004/02/skos/core#"
    xmlns:skosxl="http://www.w3.org/2008/05/skos-xl#"
    xmlns:xsd="http://www.w3.org/2001/XMLSchema"
    
    exclude-result-prefixes="f fn marc"
    version="2.0">
        
    <xsl:output encoding="UTF-8" indent="yes" method="xml" normalization-form="NFC"/>
    
    <xsl:param name="config" as="document-node()"/>
    
    <xsl:variable name="conceptSchemeSlug" select="f:slugify($config/config/scheme/conceptSchemeLabel)"/>
    <xsl:variable name="scheme" select="concat($config/config/scheme/namespace, 'concept-scheme/', $conceptSchemeSlug)"/>
    <xsl:variable name="conceptNs" select="concat($config/config/scheme/namespace, $conceptSchemeSlug, '/concept/')"/>
    
    <xsl:function name="f:conceptsToIndices" as="xsd:string+">
        <xsl:param name="context" as="node()+"/>
        <xsl:sequence select="$context/string-join((
            marc:subfield[@code = '9'],
            f:trim(marc:subfield[@code = 'a']),
            f:trim(marc:subfield[@code = 'v']),
            f:trim(marc:subfield[@code = 'x']),
            f:trim(marc:subfield[@code = 'y']),
            f:trim(marc:subfield[@code = 'z'])
            ), '|')"/>
    </xsl:function>
    
    <xsl:function name="f:conceptToURIs" as="xsd:string*">
        <xsl:param name="context" as="node()"/>
        <xsl:sequence select="
            for $id in key('indicesToIDs', f:conceptsToIndices($context), root($context))
            return concat($conceptNs, encode-for-uri($id))
            "/>
    </xsl:function>
    
    <xsl:function name="f:slugify">
        <xsl:param name="text" as="xsd:string"/>
        <xsl:value-of select="encode-for-uri(replace(lower-case($text), '\s', '-'))"/>
    </xsl:function>
    
    <xsl:function name="f:translateLang" as="xsd:string">
        <xsl:param name="code" as="xsd:string"/>
        <xsl:variable name="translated" select="
            $config/config/scheme/languageMappings/languageMapping[marc = $code]/lang
            "/>
        <xsl:choose>
            <xsl:when test="$translated"><xsl:value-of select="$translated"/></xsl:when>
            <xsl:otherwise><xsl:value-of select="$code"/></xsl:otherwise>
        </xsl:choose>
    </xsl:function>
    
    <xsl:function name="f:trim" as="xsd:string*">
        <xsl:param name="texts" as="xsd:string*"/>
        <xsl:sequence select="
            for $text in $texts
            return replace($text, '\.$', '')
            "/>
    </xsl:function>
    
    <xsl:key name="indicesToIDs"
        match="/marc:collection/marc:record/marc:controlfield[@tag = '001']"
        use="f:conceptsToIndices(../marc:datafield[contains('150 151 450 451', @tag)])"/>
    
    <xsl:template match="marc:collection">
        <rdf:RDF>
            <skos:ConceptScheme rdf:about="{$scheme}">
                <dcterms:title xml:lang="en">
                    <xsl:value-of select="$config/config/scheme/conceptSchemeLabel"/>
                </dcterms:title>
            </skos:ConceptScheme>
            <xsl:apply-templates/>
        </rdf:RDF>    
    </xsl:template>
    
    <xsl:template match="marc:record">
        <xsl:variable name="id" select="marc:controlfield[@tag = '001']"/>
        <skos:Concept rdf:about="{concat($conceptNs, encode-for-uri($id))}">
            <skos:inScheme rdf:resource="{$scheme}"/>
            <skos:notation><xsl:value-of select="$id"/></skos:notation>
            <xsl:apply-templates select="marc:controlfield|marc:datafield"/>
        </skos:Concept>
    </xsl:template>
    
    <xsl:template match="marc:leader">
        <!-- 05 - Record Status -->
        <xsl:variable name="recordStatus" select="substring(text(), 6, 1)"/>
        <xsl:choose>
            <xsl:when test="$recordStatus = 'a'">
                <!-- Increase in encoding level -->
            </xsl:when>
            <xsl:when test="$recordStatus = 'c'">
                <!-- Corrected or revised -->
            </xsl:when>
            <xsl:when test="$recordStatus = 'd'">
                <!-- Deleted -->
            </xsl:when>
            <xsl:when test="$recordStatus = 'n'">
                <!-- New -->
            </xsl:when>
            <xsl:when test="$recordStatus = 'o'">
                <!-- Obsolete -->
            </xsl:when>
            <xsl:when test="$recordStatus = 's'">
                <!-- Deleted; heading split into two or more headings -->
            </xsl:when>
            <xsl:when test="$recordStatus = 'x'">
                <!-- Deleted; heading replaced by another heading -->
            </xsl:when>
        </xsl:choose>
        
        <!-- 17 - Encoding level -->
        <xsl:variable name="encodingLevel" select="substring(text(), 18, 1)"/>
        <xsl:choose>
            <xsl:when test="$encodingLevel = 'n'">
                <!-- Complete authority record -->
            </xsl:when>
            <xsl:when test="$encodingLevel = 'o'">
                <!-- Incomplete authority record -->
            </xsl:when>
        </xsl:choose>
    </xsl:template>
    
    <!-- Field templates -->
    <xsl:template match="marc:controlfield[@tag = '005']">
        <xsl:analyze-string select="text()" regex="(\d{{4}})(\d{{2}})(\d{{2}})(\d{{2}})(\d{{2}})(\d{{2}})\.\d">
            <xsl:matching-substring>
                <!-- Unfortunately, XSL doesn't support named groups in regexes. -->
                <xsl:variable name="date" select="xsd:date(concat(regex-group(1), '-', regex-group(2), '-', regex-group(3)))"/>
                <xsl:variable name="time" select="xsd:time(concat(regex-group(4), ':', regex-group(5), ':', regex-group(6)))"/>
                <dcterms:modified rdf:datatype="http://www.w3.org/2001/XMLSchema#dateTime"><xsl:value-of select="fn:dateTime($date, $time)"/></dcterms:modified>
            </xsl:matching-substring>
            <xsl:non-matching-substring>
                <xsl:message terminate="yes">Datetime cannot be parsed: <xsl:value-of select="."/></xsl:message>
            </xsl:non-matching-substring>
        </xsl:analyze-string>
    </xsl:template>
    
    <xsl:template match="marc:controlfield[@tag = '008']">
        <!-- http://www.loc.gov/marc/authority/ad008.html -->
        
        <!-- 00-05 - Date entered on file -->
        <xsl:analyze-string select="substring(text(), 0, 7)" regex="(\d{{2}})(\d{{2}})(\d{{2}})">
            <xsl:matching-substring>
                <xsl:variable name="year" select="concat(
                    if(number(regex-group(1)) le number(substring(string(year-from-date(current-date())), 3, 5))) then '20' else '19',
                    regex-group(1))"/>
                <xsl:variable name="date" select="xsd:date(concat($year, '-', regex-group(2), '-', regex-group(3)))"/>
                <dcterms:created rdf:datatype="http://www.w3.org/2001/XMLSchema#date"><xsl:value-of select="$date"/></dcterms:created>
            </xsl:matching-substring>
        </xsl:analyze-string>
        
        <!-- 06 - Direct or indirect geographic subdivision -->
        <xsl:variable name="directOrIndirectGeographicSubdivision" select="substring(text(), 7, 1)"/>
        <xsl:choose>
            <xsl:when test="$directOrIndirectGeographicSubdivision = '#'">
                <!-- Not subdivided geographically -->
            </xsl:when>
            <xsl:when test="$directOrIndirectGeographicSubdivision = 'd'">
                <!-- Subdivided geographically-direct -->
            </xsl:when>
            <xsl:when test="$directOrIndirectGeographicSubdivision = 'i'">
                <!-- Subdivided geographically-indirect -->
            </xsl:when>
            <xsl:when test="$directOrIndirectGeographicSubdivision = 'n'">
                <!-- Not applicable -->
            </xsl:when>
            <xsl:when test="$directOrIndirectGeographicSubdivision = '|'">
                <!-- No attempt to code -->
            </xsl:when>
        </xsl:choose>
        
    </xsl:template>
    
    <xsl:template match="marc:datafield[@tag = '010']">
        <!-- Library of Congress Control Number: http://www.loc.gov/marc/authority/ad010.html -->
        <skos:exactMatch rdf:resource="{concat('http://id.loc.gov/authorities/subjects/', translate(marc:subfield[@code = 'a'], ' ', ''))}"/>
    </xsl:template>
    
    <xsl:template match="marc:datafield[@tag = '053']">
        <!-- Should we discard the label in $c? 
            Treat LCC as another skos:ConceptScheme?
            LCSH uses mads:classification for LCC.
        -->
        <mads:classification><xsl:value-of select="marc:subfield[@code ='a']"/></mads:classification>
    </xsl:template>
    
    <xsl:template match="marc:datafield[contains('150 151', @tag)]">
        <!-- http://www.loc.gov/marc/authority/ad151.html
            Geographic term: should it be in a separate concept scheme? In LCSH, everything is inside <http://id.loc.gov/authorities/subjects> scheme.
        -->
        <xsl:call-template name="mintConcept"/>
    </xsl:template>
    
    <xsl:template match="marc:datafield[@tag = '360']">
        <!-- http://loc.gov/marc/authority/ad360.html
             Complex See Also Reference-Subject -->
    </xsl:template>
    
    <xsl:template match="marc:datafield[contains('450 451', @tag)]">
        <!-- 450 - See From Tracing-Topical Term -->
        <skosxl:altLabel>
            <skosxl:Label>
                <skosxl:literalForm xml:lang="{f:translateLang(marc:subfield[@code = '9'])}"><xsl:value-of select="marc:subfield[@code ='a']"/></skosxl:literalForm>
                <xsl:call-template name="headingComponents"/>
            </skosxl:Label>
        </skosxl:altLabel>
    </xsl:template>
    
    <xsl:template match="marc:datafield[contains('550 551', @tag)][marc:subfield[@code = 'w'] = 'g']">
        <!-- Broader concept -->
        <xsl:call-template name="linkConcept">
            <xsl:with-param name="linkType">skosxl:broader</xsl:with-param>
        </xsl:call-template>
    </xsl:template>
    
    <xsl:template match="marc:datafield[contains('550 551', @tag)][marc:subfield[@code = 'w'] = 'h']">
        <!-- Narrower concept -->
        <xsl:call-template name="linkConcept">
            <xsl:with-param name="linkType">skosxl:narrower</xsl:with-param>
        </xsl:call-template>
    </xsl:template>
    
    <xsl:template match="marc:datafield[contains('550 551', @tag)][not(marc:subfield[@code = 'w'])]">
        <!-- Related concept -->
        <xsl:call-template name="linkConcept">
            <xsl:with-param name="linkType">skosxl:related</xsl:with-param>
        </xsl:call-template>
    </xsl:template>
    
    <xsl:template match="marc:datafield[@tag = '667']">
        <!-- 667 - Nonpublic General Note -->
        <!-- TODO: If it's nonpublic, should it be included in the output? -->
        <skos:note><xsl:value-of select="marc:subfield[@code='a']"/></skos:note>
    </xsl:template>
    
    <xsl:template match="marc:datafield[@tag = '670']">
        <!-- 670 - Source Data Found -->
        <schema:citation>
            <schema:CreativeWork>
                <schema:name><xsl:value-of select="marc:subfield[@code='a']"/></schema:name>
                <xsl:if test="marc:subfield[@code = 'b']">
                    <schema:description>
                        <xsl:value-of select="marc:subfield[@code = 'b']"/>
                    </schema:description>
                </xsl:if>
            </schema:CreativeWork>
        </schema:citation>
    </xsl:template>
    
    <xsl:template name="mintConcept">
        <skosxl:prefLabel>
            <skosxl:Label>
                <skos:literalForm xml:lang="{f:translateLang(marc:subfield[@code = '9'])}">
                    <xsl:value-of select="marc:subfield[@code ='a']"/>
                </skos:literalForm>
                <xsl:call-template name="headingComponents"/>
            </skosxl:Label>
        </skosxl:prefLabel>
    </xsl:template>
    
    <!-- Heading subfields dispatch -->
    <xsl:template name="headingComponents">
        <xsl:param name="codes" select="marc:subfield/@code[contains('v x y z', .)]"/>
        <xsl:if test="$codes">
            <mads:componentList rdf:parseType="Collection">
                <xsl:for-each select="$codes">
                    <rdf:Description>
                        <rdf:type>
                            <xsl:attribute name="rdf:resource">
                                <xsl:choose>
                                    <xsl:when test=". = 'v'">http://www.loc.gov/mads/rdf/v1#GenreFormElement</xsl:when><!-- Dubious mapping -->
                                    <xsl:when test=". = 'x'">http://www.loc.gov/mads/rdf/v1#Element</xsl:when>
                                    <xsl:when test=". = 'y'">http://www.loc.gov/mads/rdf/v1#TemporalElement</xsl:when>
                                    <xsl:when test=". = 'z'">http://www.loc.gov/mads/rdf/v1#GeographicElement</xsl:when>
                                </xsl:choose>
                            </xsl:attribute>
                        </rdf:type>
                        <mads:elementValue xml:lang="{f:translateLang(marc:subfield[@code = '9'])}">
                            <xsl:value-of select="marc:subfield[@code = current()]"/>
                        </mads:elementValue>
                    </rdf:Description>
                </xsl:for-each>
            </mads:componentList>
        </xsl:if>
    </xsl:template>
    
    <xsl:template name="linkConcept">
        <xsl:param name="linkType" as="xsd:string"/>
        <xsl:variable name="uris" select="f:conceptToURIs(.)"/>
        <xsl:choose>
            <xsl:when test="not(empty($uris))">
                <xsl:for-each select="$uris">
                    <xsl:element name="{$linkType}">
                        <xsl:attribute name="rdf:resource" select="."/>
                    </xsl:element>
                </xsl:for-each>
            </xsl:when>
            <!-- If no URI is found, create a blank node skos:Concept. -->
            <xsl:otherwise>
                <xsl:element name="{$linkType}">
                    <skos:Concept>
                        <xsl:call-template name="mintConcept"/>
                    </skos:Concept>
                </xsl:element>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <!-- Catch all empty template -->
    <xsl:template match="text()|@*"/>
    
</xsl:stylesheet>
