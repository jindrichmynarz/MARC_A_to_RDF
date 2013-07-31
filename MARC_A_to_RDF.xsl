<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:dcterms="http://purl.org/dc/terms/"
    xmlns:fn="http://www.w3.org/2005/xpath-functions"
    xmlns:mads="http://www.loc.gov/mads/rdf/v1#"
    xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    xmlns:skos="http://www.w3.org/2004/02/skos/core#"
    xmlns:xsd="http://www.w3.org/2001/XMLSchema"
    exclude-result-prefixes="fn"
    xpath-default-namespace="http://www.loc.gov/MARC21/slim"
    version="2.0">
    
    <!-- 
        ISSUES:
        Content:
        - Why are there English labels (e.g., "Databases") marked with "lat", ISO 639-2 code for Latin, in $9?
        - Incomplete URLs as values of 670 $a (e.g., "www.Yahoo.").
        - Heading components need to be tracked for all heading fields (150, 151, 550 etc.)
        Technical:
        - How to dispatch XSL templates based on attribute value?
        SPARQL:
        - Link skos:broader, skos:narrower and skos:related
        - Compute skos:topConceptOf
    -->
    
    <xsl:param name="namespace" select="'http://data.nli.org.il/resource/'"/>
    <xsl:variable name="scheme" select="concat($namespace, 'concept-scheme/', 'lcsh-judaica')"/>
    <xsl:variable name="conceptNs" select="concat($namespace, 'lcsh-judaica/', 'concept/')"/>
    
    <xsl:output encoding="UTF-8" indent="yes" method="xml"/>
    
    <xsl:template match="collection">
        <rdf:RDF>
            <skos:ConceptScheme rdf:about="{$scheme}">
                <dcterms:title xml:lang="en">Library of Congress Subject Headings: Judaica</dcterms:title>
            </skos:ConceptScheme>
            <xsl:apply-templates/>
        </rdf:RDF>    
    </xsl:template>
    
    <xsl:template match="record">
        <skos:Concept rdf:about="{concat($conceptNs, controlfield[@tag = '001'])}">
            <skos:inScheme rdf:resource="{$scheme}"/>
            <xsl:apply-templates select="controlfield|datafield"/>
        </skos:Concept>
    </xsl:template>
    
    <!-- Dispatching template -->
    <xsl:template match="controlfield|datafield">
        <xsl:param name="field" select="@tag"/>
        <xsl:choose>
            <xsl:when test="$field = '005'"><xsl:call-template name="f005"/></xsl:when>
            <xsl:when test="$field = '008'"><xsl:call-template name="f008"/></xsl:when>
            <xsl:when test="$field = '010'"><xsl:call-template name="f010"/></xsl:when>
            <xsl:when test="$field = '053'"><xsl:call-template name="f053"/></xsl:when>
            <xsl:when test="contains('150 151', $field)"><xsl:call-template name="f15x"/></xsl:when>
            <xsl:when test="$field = '360'"><xsl:call-template name="f360"/></xsl:when>
            <xsl:when test="contains('450 451', $field)"><xsl:call-template name="f45x"/></xsl:when>
            <xsl:when test="contains('550 551', $field)">
                <xsl:choose>
                    <xsl:when test="subfield[@code='w'] = 'g'"><xsl:call-template name="broader"/></xsl:when>
                    <xsl:when test="subfield[@code='w'] = 'h'"><xsl:call-template name="narrower"/></xsl:when>
                    <xsl:when test="not(subfield[@label = 'w'])"><xsl:call-template name="related"/></xsl:when>
                </xsl:choose>
            </xsl:when>
            <xsl:when test="$field = '667'"><xsl:call-template name="f667"/></xsl:when>
            <xsl:when test="$field = '670'"><xsl:call-template name="f670"/></xsl:when>
        </xsl:choose>
    </xsl:template>
    
    <!-- Field templates -->
    <xsl:template name="f005">
        <!--  Model as a change note (as LCSH does)? -->
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
    
    <xsl:template name="f008">
        <!-- TODO: http://www.loc.gov/marc/authority/ad008.html -->
    </xsl:template>
    
    <xsl:template name="f010">
        <!-- Library of Congress Control Number: http://www.loc.gov/marc/authority/ad010.html -->
        <!-- Use for linking to LCSH -->
        <skos:exactMatch rdf:resource="{concat('http://id.loc.gov/authorities/subjects/', translate(subfield[@code = 'a'], ' ', ''))}"/>
    </xsl:template>
    
    <xsl:template name="f053">
        <!-- Should we discard the label in $c? 
            Treat LCC as another skos:ConceptScheme?
            LCSH uses mads:classification for LCC.
        -->
        <mads:classification><xsl:value-of select="subfield[@code ='a']"/></mads:classification>
    </xsl:template>
    
    <xsl:template name="f15x">
        <!-- http://www.loc.gov/marc/authority/ad151.html
            Geographic term: should it be in a separate concept scheme? In LCSH, everything is inside <http://id.loc.gov/authorities/subjects> scheme.
        -->
        <skos:prefLabel xml:lang="{subfield[@code = '9']}"><xsl:value-of select="subfield[@code ='a']"/></skos:prefLabel>
        <xsl:call-template name="headingComponents"/>
    </xsl:template>
    
    <xsl:template name="f360">
        
    </xsl:template>
    
    <xsl:template name="f45x">
        <skos:altLabel xml:lang="{subfield[@code = '9']}"><xsl:value-of select="subfield[@code ='a']"/></skos:altLabel>
    </xsl:template>
    
    <xsl:template name="broader">
        <!-- Needs to be transformed to link via SPARQL -->
        <skos:broader>
            <xsl:call-template name="linkedBlankNodeConcept"/>
        </skos:broader>
    </xsl:template>
    
    <xsl:template name="narrower">
        <!-- Needs to be transformed to link via SPARQL -->
        <skos:narrower>
            <xsl:call-template name="linkedBlankNodeConcept"/>
        </skos:narrower>
    </xsl:template>
    
    <xsl:template name="related">
        <!-- Needs to be transformed to link via SPARQL -->
        <skos:related>
            <xsl:call-template name="linkedBlankNodeConcept"/>
        </skos:related>
    </xsl:template>
    
    <xsl:template name="f667">
        <skos:note><xsl:value-of select="subfield[@code='a']"/></skos:note>
    </xsl:template>
    
    <xsl:template name="f670">
        <!-- $a is source? 
            $b is scope note?
        -->
        <dcterms:source><xsl:value-of select="subfield[@code='a']"/></dcterms:source>
    </xsl:template>
    
    <!-- Heading subfields dispatch -->
    <xsl:template name="headingComponents">
        <xsl:param name="code" select="subfield/@code"/>
        <xsl:if test="$code = 'v' or $code = 'y' or $code = 'y' or $code = 'z'">
            <mads:componentlist rdf:parseType="Collection">
                <xsl:choose>
                    <xsl:when test="$code = 'v'"><xsl:call-template name="headingSubfieldV"/></xsl:when>
                    <xsl:when test="$code = 'x'"><xsl:call-template name="headingSubfieldX"/></xsl:when>
                    <xsl:when test="$code = 'y'"><xsl:call-template name="headingSubfieldY"/></xsl:when>
                    <xsl:when test="$code = 'z'"><xsl:call-template name="headingSubfieldZ"/></xsl:when>
                </xsl:choose>
            </mads:componentlist>
        </xsl:if>
    </xsl:template>
    
    <!-- Heading subfields templates -->
    <xsl:template name="headingSubfieldV">
            <rdf:type rdf:resource="http://www.loc.gov/mads/rdf/v1#Authority"/>
            <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template name="headingSubfieldX">
        <mads:componentlist rdf:parseType="Collection">
        </mads:componentlist>    
    </xsl:template>
    
    <xsl:template name="headingSubfieldY">
        <mads:componentlist rdf:parseType="Collection">
        </mads:componentlist>    
    </xsl:template>
    
    <xsl:template name="headingSubfieldZ">
        <mads:componentlist rdf:parseType="Collection">
        </mads:componentlist>    
    </xsl:template>
    
    <xsl:template name="linkedBlankNodeConcept">
        <rdf:type resource="http://www.w3.org/2004/02/skos/core#Concept"/>
        <skos:prefLabel xml:lang="{subfield[@code = '9']}"><xsl:value-of select="subfield[@code='a']"/></skos:prefLabel>
    </xsl:template>
    
</xsl:stylesheet>