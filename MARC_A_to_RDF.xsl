<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:f="http://opendata.cz/xslt/functions#"
    xmlns:fn="http://www.w3.org/2005/xpath-functions"
    
    xmlns:dcterms="http://purl.org/dc/terms/"
    xmlns:mads="http://www.loc.gov/mads/rdf/v1#"
    xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    xmlns:schema="http://schema.org/"
    xmlns:skos="http://www.w3.org/2004/02/skos/core#"
    xmlns:skosxl="http://www.w3.org/2008/05/skos-xl#"
    xmlns:xsd="http://www.w3.org/2001/XMLSchema"
    
    exclude-result-prefixes="f fn"
    xpath-default-namespace="http://www.loc.gov/MARC21/slim"
    version="2.0">
    
    <!-- 
        ISSUES:
        Content:
        - Why are there English labels (e.g., "Databases") marked with "lat", ISO 639-2 code for Latin, in $9?
        - Incomplete URLs as values of 670 $a (e.g., "www.Yahoo.").
        - Heading components need to be tracked for all heading fields (150, 151, 550 etc.)
        SPARQL:
        - Link skos:broader, skos:narrower and skos:related / might be done with <xsl:key>
        - Compute skos:topConceptOf
    -->
    
    <xsl:output encoding="UTF-8" indent="yes" method="xml"/>
    
    <xsl:param name="config"/>
    
    <xsl:variable name="conceptSchemeSlug" select="f:slugify($config/config/conceptSchemaLabel)"/>
    <xsl:variable name="scheme" select="concat($config/config/namespace, 'concept-scheme/', $conceptSchemeSlug)"/>
    <xsl:variable name="conceptNs" select="concat($config/config/namespace, $conceptSchemeSlug, '/concept/')"/>
    
    <xsl:function name="f:labelToURIs" as="xsd:string*">
        <xsl:param name="context" as="node()"/>
        <xsl:param name="key" as="xsd:string"/>
        <xsl:variable name="ids" select="key('labelToID', $key, root($context))"/>
        <!-- <xsl:message>IDs: <xsl:value-of select="$ids"/></xsl:message> -->
        <xsl:choose>
            <xsl:when test="$ids">
                <xsl:value-of select="
                    for $id in $ids
                    return concat($conceptNs, encode-for-uri($id))
                    "/>
            </xsl:when>
            <!-- <xsl:message>URI for key <xsl:value-of select="$key"/> cannot be found.</xsl:message> -->
        </xsl:choose>
    </xsl:function>
    
    <xsl:function name="f:trim" as="xsd:string*">
        <xsl:param name="texts" as="xsd:string*"/>
        <xsl:choose>
            <xsl:when test="$texts">
                <xsl:value-of select="
                    for $text in $texts
                    return replace($text, '\.$', '')
                    "/>
            </xsl:when>
        </xsl:choose>
    </xsl:function>
    
    <xsl:function name="f:slugify">
        <xsl:param name="text" as="xsd:string"/>
        <xsl:value-of select="encode-for-uri(replace(lower-case($text), '\s', '-'))"/>
    </xsl:function>
    
    <xsl:key name="labelToID"
        match="/collection/record/controlfield[@tag = '001']"
        use="../datafield[contains('150 151 450 451', @tag)]/string-join((
            subfield[@code = '9'],
            f:trim(subfield[@code = 'a']),
            f:trim(subfield[@code = 'v']),
            f:trim(subfield[@code = 'x']),
            f:trim(subfield[@code = 'y']),
            f:trim(subfield[@code = 'z'])
            ), '|')"/>
    
    <xsl:template match="collection">
        <rdf:RDF>
            <skos:ConceptScheme rdf:about="{$scheme}">
                <dcterms:title xml:lang="en"><xsl:value-of select="$conceptSchemeLabel"/></dcterms:title>
            </skos:ConceptScheme>
            <xsl:apply-templates/>
        </rdf:RDF>    
    </xsl:template>
    
    <xsl:template match="record">
        <xsl:variable name="id" select="controlfield[@tag = '001']"/>
        <skos:Concept rdf:about="{concat($conceptNs, encode-for-uri($id))}">
            <skos:inScheme rdf:resource="{$scheme}"/>
            <skos:notation><xsl:value-of select="$id"/></skos:notation>
            <xsl:apply-templates select="controlfield|datafield"/>
        </skos:Concept>
    </xsl:template>
    
    <xsl:template match="leader">
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
    <xsl:template match="controlfield[@tag = '005']">
        <!--  TODO: Model as a change note (as LCSH does)? -->
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
    
    <xsl:template match="controlfield[@tag = '008']">
        <!-- TODO: http://www.loc.gov/marc/authority/ad008.html -->
        
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
    
    <xsl:template match="datafield[@tag = '010']">
        <!-- Library of Congress Control Number: http://www.loc.gov/marc/authority/ad010.html -->
        <!-- Use for linking to LCSH -->
        <skos:exactMatch rdf:resource="{concat('http://id.loc.gov/authorities/subjects/', translate(subfield[@code = 'a'], ' ', ''))}"/>
    </xsl:template>
    
    <xsl:template match="datafield[@tag = '053']">
        <!-- Should we discard the label in $c? 
            Treat LCC as another skos:ConceptScheme?
            LCSH uses mads:classification for LCC.
        -->
        <mads:classification><xsl:value-of select="subfield[@code ='a']"/></mads:classification>
    </xsl:template>
    
    <xsl:template match="datafield[contains('150 151', @tag)]">
        <!-- http://www.loc.gov/marc/authority/ad151.html
            Geographic term: should it be in a separate concept scheme? In LCSH, everything is inside <http://id.loc.gov/authorities/subjects> scheme.
        -->
        <xsl:call-template name="mintConcept">
            <xsl:with-param name="context" select="."/>
        </xsl:call-template>
    </xsl:template>
    
    <xsl:template match="datafield[@tag = '360']">
        
    </xsl:template>
    
    <xsl:template match="datafield[contains('450 451', @tag)]">
        <!-- 450 - See From Tracing-Topical Term -->
        <skosxl:altLabel>
            <skosxl:Label>
                <skosxl:literalForm xml:lang="{subfield[@code = '9']}"><xsl:value-of select="subfield[@code ='a']"/></skosxl:literalForm>
                <xsl:call-template name="headingComponents">
                    <xsl:with-param name="context" select="."/>
                </xsl:call-template>
            </skosxl:Label>
        </skosxl:altLabel>
    </xsl:template>
    
    <xsl:template match="datafield[contains('550 551', @tag)][subfield[@code = 'w'] = 'g']">
        <!-- Broader concept -->
        <!-- TODO: Needs to be transformed to link -->
        <xsl:call-template name="linkConcept">
            <xsl:with-param name="context" select="."/>
            <xsl:with-param name="linkType">skosxl:broader</xsl:with-param>
        </xsl:call-template>
    </xsl:template>
    
    <xsl:template match="datafield[contains('550 551', @tag)][subfield[@code = 'w'] = 'h']">
        <!-- Narrower concept -->
        <!-- TODO: Needs to be transformed to link -->
        <xsl:call-template name="linkConcept">
            <xsl:with-param name="context" select="."/>
            <xsl:with-param name="linkType">skosxl:narrower</xsl:with-param>
        </xsl:call-template>
    </xsl:template>
    
    <xsl:template match="datafield[contains('550 551', @tag)][not(subfield[@code = 'w'])]">
        <!-- Related concept -->
        <!-- TODO: Needs to be transformed to link -->
        <xsl:call-template name="linkConcept">
            <xsl:with-param name="context" select="."/>
            <xsl:with-param name="linkType">skosxl:related</xsl:with-param>
        </xsl:call-template>
    </xsl:template>
    
    <xsl:template match="datafield[@tag = '667']">
        <!-- 667 - Nonpublic General Note -->
        <!-- TODO: If it's nonpublic, should it be included in the output? -->
        <skos:note><xsl:value-of select="subfield[@code='a']"/></skos:note>
    </xsl:template>
    
    <xsl:template match="datafield[@tag = '670']">
        <!-- 670 - Source Data Found -->
        <schema:citation>
            <schema:CreativeWork>
                <schema:name><xsl:value-of select="subfield[@code='a']"/></schema:name>
                <xsl:if test="subfield[@code = 'b']">
                    <schema:description><xsl:value-of select="subfield[@code = 'b']"/></schema:description>
                </xsl:if>
            </schema:CreativeWork>
        </schema:citation>
    </xsl:template>
    
    <xsl:template name="mintConcept">
        <xsl:param name="context"/>
        <skosxl:prefLabel>
            <skosxl:Label>
                <skos:literalForm xml:lang="{$context/subfield[@code = '9']}"><xsl:value-of select="$context/subfield[@code ='a']"/></skos:literalForm>
                <xsl:call-template name="headingComponents">
                    <xsl:with-param name="context" select="$context"/>
                </xsl:call-template>
            </skosxl:Label>
        </skosxl:prefLabel>
    </xsl:template>
    
    <!-- Heading subfields dispatch -->
    <xsl:template name="headingComponents">
        <xsl:param name="context"/>
        <xsl:param name="codes" select="$context/subfield/@code[contains('v x y z', .)]"/>
        <xsl:if test="$codes">
            <mads:componentlist rdf:parseType="Collection">
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
                        <mads:elementValue xml:lang="{$context/subfield[@code = '9']}"><xsl:value-of select="$context/subfield[@code = current()]"/></mads:elementValue>
                    </rdf:Description>
                </xsl:for-each>
            </mads:componentlist>
        </xsl:if>
    </xsl:template>
    
    <xsl:template name="linkConcept">
        <xsl:param name="context" as="node()"/>
        <xsl:param name="linkType" as="xsd:string"/>
        <xsl:variable name="key" select="$context/string-join((
            subfield[@code ='9'],
            f:trim(subfield[@code ='a']),
            f:trim(subfield[@code = 'v']),
            f:trim(subfield[@code = 'x']),
            f:trim(subfield[@code = 'y']),
            f:trim(subfield[@code = 'z'])
            ), '|')"/>
        <xsl:variable name="uris" select="f:labelToURIs($context, $key)"/>
        <xsl:message>URIs: <xsl:value-of select="$uris"/></xsl:message>
        <xsl:choose>
            <xsl:when test="$uris">
                <xsl:for-each select="$uris">
                    <xsl:element name="{$linkType}">
                        <xsl:attribute name="rdf:resource" select="."/>
                    </xsl:element>
                </xsl:for-each>
            </xsl:when>
            <xsl:otherwise>
                <xsl:message>No URIs</xsl:message>
                <skos:Concept>
                    <xsl:call-template name="mintConcept">
                        <xsl:with-param name="context" select="$context"/>
                    </xsl:call-template>
                </skos:Concept>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <!-- Catch all empty template -->
    <xsl:template match="text()|@*"/>
    
</xsl:stylesheet>