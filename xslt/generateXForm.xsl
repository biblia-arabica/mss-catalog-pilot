<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet 
    xmlns="http://www.w3.org/1999/xhtml" 
    xmlns:tei="http://www.tei-c.org/ns/1.0" 
    xmlns:sc="http://www.ascc.net/xml/schematron" 
    xmlns:xf="http://www.w3.org/2002/xforms"
    xmlns:ev="http://www.w3.org/2001/xml-events"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" 
    xmlns:local="http://syriaca.org/ns"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="3.0">
    <!-- 
        Generate XForms for TEI creation. 
        Example of TEI XForms generated from ODD. Run as an eXist-db application. Resulting TEI can be saved to eXist-db, downloaded to local filesystem, or saved to a GitHub repository
        
        Expectations: 
        
        Requirements: 
            - config.xml; see example
            - TEI template, example record
            - Local schema constrainst, as an ODD file
            - Main schema as an ODD file
            
        Version: 
        

        NOTES: 
            use blank template to build form, each element in template against the schema?            
            Steps
            Create model
            Create templates - maybe the same as create model
            Create view
            
            
    -->
    <xsl:param name="config" select="'config.xml'"/>
    <xsl:variable name="configDoc" select="document($config)"/>
    <!-- Local schema customizations -->
    <xsl:variable name="localSchemaDoc" select="document($configDoc//localSchema/@src)"/>
    <!-- Global schema -->
    <xsl:variable name="globalSchemaDoc" select="document($configDoc//globalSchema/@src)"/>
    <!-- Template for building form -->
    <xsl:variable name="template" select="document($configDoc//xmlTemplate/@src)"/>
    
    <xsl:output name="xform" encoding="UTF-8" method="xhtml" indent="yes" omit-xml-declaration="yes" xml:space="preserve" xpath-default-namespace="http://www.w3.org/1999/xhtml"/>
    <xsl:output name="tei" encoding="UTF-8" method="xml" indent="yes" xpath-default-namespace="http://www.tei-c.org/ns/1.0"/>
    
    <!-- Check schema for element rules
        WS:Note will need to refine so we get local/global and then check against each other for final set of rules. 
    -->
    <!-- Helper functions -->
    <xsl:function name="local:localElementRules">
        <xsl:param name="elementName"/>
        <xsl:for-each select="$localSchemaDoc//descendant-or-self::*:elementSpec[@ident=$elementName]">
            <xsl:copy-of select="."/>
        </xsl:for-each>
    </xsl:function>
    <xsl:function name="local:globalElementRules">
        <xsl:param name="elementName"/>
        <xsl:for-each select="$globalSchemaDoc//descendant-or-self::*:elementSpec[@ident=$elementName]">
            <xsl:copy-of select="."/>
        </xsl:for-each>
    </xsl:function>
    <xsl:function name="local:parentElementRules">
        <xsl:param name="parentElementName"/>
        <xsl:for-each select="$localSchemaDoc//descendant-or-self::tei:elementSpec[@ident=$parentElementName]">
            <xsl:copy-of select="."/>
        </xsl:for-each>
    </xsl:function>
    <xsl:function name="local:elementRules">
        <xsl:param name="elementName"/>
        <rules xmlns="http://www.tei-c.org/ns/1.0">
            <local>
                <xsl:for-each select="$localSchemaDoc//descendant-or-self::*:elementSpec[@ident=$elementName]">
                    <xsl:copy-of select="."/>
                </xsl:for-each>
            </local>
            <global>
                <xsl:for-each select="$globalSchemaDoc//descendant-or-self::*:elementSpec[@ident=$elementName]">
                    <xsl:copy-of select="."/>
                </xsl:for-each>
            </global> 
        </rules>
    </xsl:function>
    <!-- get available child elements for specified element -->
    <xsl:function name="local:availableChildren">
        <xsl:param name="elementName"/>
        <!-- Still need to handle classRefs -->
        <xsl:variable name="globalElements" select="local:globalElementRules($elementName)/descendant-or-self::*:content/descendant::*:elementRef/@key"/>
        <xsl:variable name="localElements" select="local:localElementRules($elementName)/descendant-or-self::*:content/descendant::*:elementRef/@key"/>
        <xsl:for-each-group select="$globalElements | $localElements" group-by=".">
            <xsl:sort select="."/>
            <xsl:element name="{.}" namespace="http://www.tei-c.org/ns/1.0"/>
        </xsl:for-each-group>
    </xsl:function>
    <xsl:function name="local:availableAttributes">
        <xsl:param name="elementName"/>
        <!-- Still need to handle classRefs -->
        <xsl:variable name="globalAttributes" select="local:globalElementRules($elementName)/descendant-or-self::*:content/descendant::*:attList/*:attDef"/>
        <xsl:variable name="localAttributes" select="local:localElementRules($elementName)/descendant-or-self::*:content/descendant::*:attList/*:attDef"/>
        <xsl:for-each-group select="$globalAttributes | $localAttributes" group-by="@ident">
            <xsl:sort select="@ident"/>
            <xsl:element name="{@ident}" namespace="http://www.tei-c.org/ns/1.0">
                <xsl:copy-of select="."/>
            </xsl:element>
        </xsl:for-each-group>
    </xsl:function>
    <!-- 
        Make into a reusable function
        <xsl:variable name="availableChildren">

    <xsl:variable name="globalElements" select="$globalElementRules/descendant-or-self::*:content/descendant::*:elementRef/@key"/>
    <xsl:variable name="localElements" select="$localElementRules/descendant-or-self::*:content/descendant::*:elementRef/@key"/>
    <xsl:for-each-group select="$globalElements | $localElements" group-by=".">
        <xsl:sort select="."/>
        <xsl:element name="{.}" namespace="http://www.tei-c.org/ns/1.0"/>
    </xsl:for-each-group>
    </xsl:variable> 
    -->
    <!-- 
        Steps: 
        Generate controlled values
        genreate attributes
        generate reuseable elements/attributes
        generate xf:bind rules based on schema
        generate instances 
        
    -->
    
    <xsl:template match="/">
        <!-- Output XForm for each subfomr in config.xml, if no subforms, output full TEI record (not recommended). -->
        <xsl:for-each select="$configDoc//subform">
            <xsl:variable name="formName" select="@formName"/>
            <xsl:result-document href="{$formName}.xhtml" format="xform">
                <xsl:call-template name="xform">
                    <xsl:with-param name="subform" select="."/>
                </xsl:call-template>
            </xsl:result-document>
        </xsl:for-each>
        <!-- Output controlledValues template file -->
        <xsl:result-document href="controlledValues.xml" format="tei">
           <xsl:call-template name="controlledValues"/>
        </xsl:result-document>
        <xsl:result-document href="elementTemplate.xml" format="tei">
            <!--<xsl:call-template name="template"/>-->
            <xsl:call-template name="elementTemplate"/>
        </xsl:result-document>
        <xsl:result-document href="attributesTemplate.xml" format="tei">
            <!--<xsl:call-template name="template"/>-->
            <xsl:call-template name="attributesTemplate"/>
        </xsl:result-document>
        <!-- <attDef ident="anchored" usage="opt"> -->
    </xsl:template>
    <xsl:template name="xform">
        <xsl:param name="subform"/>
                <xsl:text disable-output-escaping='yes'>&lt;!DOCTYPE html&gt;</xsl:text>
                <html xmlns="http://www.w3.org/1999/xhtml" 
                    xmlns:ev="http://www.w3.org/2001/xml-events" 
                    xmlns:tei="http://www.tei-c.org/ns/1.0" 
                    xmlns:xf="http://www.w3.org/2002/xforms">
                    <head>
                        <title><xsl:value-of select="$configDoc//formTitle"/></title>
                        <meta name="author" content="{$configDoc//formAuthor}"/>
                        <meta name="description" content="{$configDoc//formDesc}"/>
                        <link rel="stylesheet" type="text/css" href="resources/bootstrap/css/bootstrap.min.css"/>
                        <link rel="stylesheet" type="text/css" href="resources/css/xforms.css"/>
                        <link href="resources/jquery-ui/jquery-ui.min.css" rel="stylesheet"/>
                        <script type="text/javascript" src="resources/js/jquery.min.js"/>
                        <script type="text/javascript" src="resources/bootstrap/js/bootstrap.min.js"/>
                        <xf:model id="m-mss">
                            <!-- Create instances -->
                            <xf:instance xmlns="http://www.tei-c.org/ns/1.0" id="i-rec" src="forms/templates/{$configDoc//xmlTemplate/@src}"/>
                            <xf:instance xmlns="http://www.tei-c.org/ns/1.0" id="i-template" src="forms/templates/template.xml"/>
                            <xf:instance xmlns="http://www.tei-c.org/ns/1.0" id="i-ctr-vals" src="forms/templates/controlledValues.xml"/>
                            <xf:instance xmlns="http://www.tei-c.org/ns/1.0" id="i-elementTemplate" src="forms/templates/elementTemplate.xml"/>
                            <!-- i-insert-elements -->
                            <xf:instance xmlns="http://www.tei-c.org/ns/1.0" id="i-insert-elements">
                                <TEI><element></element></TEI>
                            </xf:instance>
                            <!-- Build contstraints 
                            <xsl:for-each select="$template/child::*">
                                <xsl:apply-templates mode="formRules"/>
                            </xsl:for-each>
                            -->
                            <!-- Create optional lookups -->
                            <!-- Submissions -->
                            <!-- For error messages from server -->  
                            <xf:instance id="i-submission">
                                <response status="success">
                                    <message>Submission result</message>
                                </response>
                            </xf:instance>
                            
                            <!-- Download XML to your desktop -->
                            <xf:submission id="s-download-xml" ref="instance('i-rec')" show="new" method="post" replace="all" action="form.xq?form=forms/download.xml?type=download"/>
                            
                            <!-- Download View XML in browser -->
                            <xf:submission id="s-view-xml" ref="instance('i-rec')" show="new" method="post" replace="all" action="services/submit.xql?type=view"/>
                            
                            <!-- Save record to Database -->
                            <xf:submission id="s-save" ref="instance('i-rec')" replace="instance" instance="i-submission" action="services/submit.xql?type=save" method="post">
                                <xf:action ev:event="xforms-submit-done">
                                    <xf:message ref="instance('i-submission')//*:message"/>
                                </xf:action>
                                <xf:action ev:event="xforms-submit-error">
                                    <xf:message ref="instance('i-submission')//*:message"/>
                                </xf:action>
                            </xf:submission>
                            
                            <!-- Save record to github -->
                            <xf:submission id="s-github" ref="instance('i-rec')" replace="instance" instance="i-submission" action="services/submit.xql?type=github" method="post">
                                <xf:action ev:event="xforms-submit-done">
                                    <xf:message ref="instance('i-submission')//*:message"/>
                                </xf:action>
                                <xf:action ev:event="xforms-submit-error">
                                    <xf:message ev:event="xforms-submit-error" level="modal">Unable to submit your additions at this time, you may download your changes and email them to us.</xf:message>
                                </xf:action>
                            </xf:submission>
                        </xf:model>
                    </head>
                    <body>       
                        <div class="section xforms">
                            <xsl:call-template name="submission"/>
                            <h1><xsl:value-of select="$subform/@formName"/></h1>
                            <!-- Create view (inputs) -->
                            <!-- 
                                 1. Check template for element
                                 2. Check template and/or schema for optional attributes and child elements
                                 3. If attributes, create inputs and dropdowns, with controlled values if specified in schema
                                 3. If terminal element, build input options.
                             -->
                            <xsl:variable name="xpath" select="string($subform/@xpath)"/>
                            <xsl:variable name="subsequence">
                                <xsl:evaluate xpath="$xpath" context-item="$template"/>
                            </xsl:variable>
                            <xsl:for-each select="$subsequence/element()">
<!--                                <xsl:apply-templates mode="formElement"/>-->
                                <xsl:variable name="elementPath" select="replace(replace(replace(replace(path(.),'Q\{http://www.tei-c.org/ns/1.0\}','tei:'),'tei:TEI','/'),'\[[0-9]+\]',''),'///','//')"/>
                                <xsl:variable name="elementName" select="local-name(.)"/>
<!--                                <elementPath><xsl:value-of select="$elementPath"/></elementPath>-->
                                <xsl:call-template name="xformElementUI">
                                    <xsl:with-param name="elementName" select="$elementName"/>
                                    <xsl:with-param name="path"/>
                                    <xsl:with-param name="min"/>
                                    <xsl:with-param name="max"/>
                                </xsl:call-template>
                                <!-- 
                                <xsl:if test="child::element()">
                                    <xsl:for-each select="child::element()">
                                        <xsl:variable name="childPath" select="replace(replace(replace(replace(path(.),'Q\{http://www.tei-c.org/ns/1.0\}','tei:'),'tei:TEI','/'),'\[[0-9]+\]',''),'///','//')"/>
                                        <xsl:call-template name="formElement">
                                            <xsl:with-param select="$childPath" name="path"/>
                                        </xsl:call-template>
                                    </xsl:for-each>
                                </xsl:if>
                                -->
                            </xsl:for-each>
                            <xsl:call-template name="submission"/>
                        </div>
                    </body>
                </html>
    </xsl:template>
    <xsl:template name="submission">
        <div class="submission pull-right">
            <xf:submit class="btn btn-default" submission="s-github" appearance="minimal">
                <xf:label><span class="glyphicon glyphicon-save-file"/> Submit to GitHub </xf:label>
            </xf:submit>
            <xf:submit class="btn btn-default" submission="s-save" appearance="minimal">
                <xf:label><span class="glyphicon glyphicon-save-file"/> Save to Database </xf:label>    
            </xf:submit>
            <xf:submit class="btn btn-default" submission="s-download-xml" appearance="minimal">
                <xf:label><span class="glyphicon glyphicon-save-file"/> Download XML </xf:label>
            </xf:submit>
            <xf:submit class="btn btn-default" submission="s-view-xml" appearance="minimal">
                <xf:label><span class="glyphicon glyphicon-save-file"/> View XML </xf:label>
            </xf:submit>
        </div>
    </xsl:template>
    <xsl:template name="controlledValues">
        <!-- Build a template with all the controlled values, referenced by the xforms model -->
        <xsl:for-each select="$localSchemaDoc/child::*">
            <!-- <xsl:call-template name="buildXFormsElement"/> -->
            <TEI xmlns="http://www.tei-c.org/ns/1.0" xml:id="controlledValues" xml:lang="en">
                <xsl:apply-templates mode="controlledValues"/>
            </TEI>
        </xsl:for-each>
    </xsl:template>
    <xsl:template name="template">
        <!-- WS:Note: add a fake attribute for repeatable? 
            Build a template with all possible child elements and attributes, referenced by the xforms model 
        -->
        <xsl:for-each select="$template/element()">
            <TEI xmlns="http://www.tei-c.org/ns/1.0" xml:id="controlledValues" xml:lang="en">
                <xsl:apply-templates mode="template"/>
            </TEI>
        </xsl:for-each>
    </xsl:template>
    <xsl:template match="tei:elementSpec" mode="controlledValues">
        <xsl:if test="tei:attList/tei:attDef[tei:valList[@type='closed']]">
            <xsl:element name="{string(@ident)}" namespace="http://www.tei-c.org/ns/1.0">
                <xsl:for-each select="tei:attList/tei:attDef[tei:valList[@type='closed']]">
                    <xsl:element name="{string(@ident)}" namespace="http://www.tei-c.org/ns/1.0">
                        <xsl:copy-of select="tei:valList[@type='closed']"/>
                    </xsl:element>
                </xsl:for-each>
            </xsl:element>    
        </xsl:if>
    </xsl:template>
    <xsl:template match="text()" mode="controlledValues"/>
    <xsl:template match="*" mode="formElement">
        <xsl:variable name="currentElement" select="."/>
        <xsl:variable name="elementName" select="local-name(.)"/>
        <xsl:variable name="parentElementName" select="local-name(parent::*[1])"/>
        <xsl:variable name="availableChildren" select="local:availableChildren($elementName)"/>
        <xsl:variable name="availableAttributes" select="local:availableAttributes($elementName)"/>
        <xsl:variable name="elementRules" select="local:elementRules($elementName)"/>
        
        <xsl:variable name="path" select="replace(replace(replace(replace(path(.),'Q\{http://www.tei-c.org/ns/1.0\}','tei:'),'tei:TEI','/'),'\[[0-9]+\]',''),'///','//')"/>
        
        <xsl:variable name="xformsElement">
            <xsl:choose>
                <xsl:when test="local:parentElementRules($parentElementName)/descendant::tei:elementRef[@key=$elementName][@maxOccurs='unbounded']">repeat</xsl:when>
                <xsl:when test="$elementRules/descendant::tei:sequence[@maxOccurs='unbounded']">repeat</xsl:when>
                <xsl:otherwise>group</xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <!-- 
            Create xforms element, options: repeat, group, input, text, or call child
            check schema for text or child
            check for repeated, max/min #
            check for childrend 
            check for attributes
            
            Maybe generate a template for each model.* so I do not have an impossibly nested form? 
            generate children in correct order according to schema
        -->
        <div style="border:1px solid grey; padding:2px;">
            <xsl:element name="{$xformsElement}" namespace="http://www.w3.org/2002/xforms">
                <xsl:if test="$elementRules/descendant::tei:content/tei:textNode or $elementRules/descendant::tei:content/tei:alternate/descendant::tei:textNode">
                    <!-- Text area -->        
                    <p>Text area</p>
                </xsl:if>
                <xsl:if test="$elementRules">
                    <xsl:for-each-group select="$elementRules//tei:elementSpec/tei:content/descendant-or-self::tei:elementRef" group-by="@key">
                        <xsl:call-template name="xformElementUI">
                            <xsl:with-param name="elementName" select="@key"/>
                            <xsl:with-param name="path" select="$path"/>
                            <xsl:with-param name="min" select="@minOccurs"/>
                            <xsl:with-param name="max" select="@maxOccurs"/>
                        </xsl:call-template>
                    </xsl:for-each-group>
                </xsl:if>
            </xsl:element>
        </div>
    </xsl:template>
    <!-- Build xforms UI elements, inputs, repeats, groups, etc -->
    <xsl:template name="xformElementUI">
        <xsl:param name="elementName"/>
        <xsl:param name="path"/>
        <xsl:param name="min"/>
        <xsl:param name="max"/>        
        <xsl:variable name="availableChildren" select="local:availableChildren($elementName)"/>
        <xsl:variable name="availableAttributes" select="local:availableAttributes($elementName)"/>
        <xsl:variable name="elementRules" select="local:elementRules($elementName)"/>
        <xsl:variable name="path" select="concat($path,'/tei:',$elementName)"/>
        <!-- 
            Create xforms element, options: repeat, group, input, text, or call child
            check schema for text or child
            check for repeated, max/min # - done
            check for childrend  - done
            check for attributes - 
            
            Maybe generate a template for each model.* so I do not have an impossibly nested form? 
            generate children in correct order according to schema
        -->
        <xsl:variable name="maxOccur">
            <xsl:choose>
                <xsl:when test="$max !='' "><xsl:value-of select="$max"/></xsl:when>
                <xsl:when test="$elementRules/tei:content/tei:sequence[@maxOccur]"><xsl:value-of select="string($elementRules/tei:content/tei:sequence/@maxOccur)"/></xsl:when>
                <xsl:otherwise></xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:variable name="minOccur">
            <xsl:choose>
                <xsl:when test="$max !='' "><xsl:value-of select="$min"/></xsl:when>
                <xsl:when test="$elementRules/tei:content/tei:sequence[@minOccur]"><xsl:value-of select="string($elementRules/tei:content/tei:sequence/@minOccur)"/></xsl:when>
                <xsl:otherwise></xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:variable name="xformsElement">
            <xsl:choose>
                <xsl:when test="$max = 'unbounded' or $max = ''">repeat</xsl:when>
                <xsl:otherwise>group</xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
     
        <!-- Create a min.max variable that test for param or element rules  -->
        <div style="border:1px solid grey; padding:2px;">
            <xsl:element name="{$xformsElement}" namespace="http://www.w3.org/2002/xforms">
                <!-- Add title, drop down of available attributes and available elements -->
                <!-- Do attributes, check local, then global, have to check local for changes, replacements etc -->
                <xsl:variable name="elementRef">instance('i-rec')/<xsl:value-of select="$path"/></xsl:variable>
                <xsl:attribute name="ref" select="$elementRef"/>
                <xsl:attribute name="id" select="generate-id(.)"/>
                <xsl:attribute name="class">xformsGroup</xsl:attribute>
                <div class="inlineBlock">
                    <path><xsl:value-of select="$path"/></path>
                    <!-- Test if repeatable, if required etc. sequence minOccurs="1" maxOccurs="1"-->
                    <xsl:choose>
                        <xsl:when test="$minOccur">
                            <xsl:choose>
                                <xsl:when test="$minOccur castable as xs:integer">
                                    <xsl:choose>
                                        <xsl:when test="xs:integer($minOccur) = 0">
                                            <!-- If 0 required, allow delete button all the time -->
                                            <xf:trigger appearance="minimal" class="btn remove inline">
                                                <xf:label/>
                                                <xf:delete ev:event="DOMActivate" ref="."/>
                                            </xf:trigger>
                                        </xsl:when>
                                        <xsl:when test="xs:integer($minOccur) = 1">
                                            <!-- If one is required allow delete only if sibling elements exist -->
                                            <xf:trigger appearance="minimal" class="btn remove inline" ref=".[following-sibling::tei:{$elementName}]">
                                                <xf:label/>
                                                <xf:delete ev:event="DOMActivate" ref="."/>
                                            </xf:trigger>
                                        </xsl:when>
                                        <xsl:when test="xs:integer($minOccur) gt 1">
                                            <!-- WS:Note, not sure what to do here, or if this is even likely -->
                                        </xsl:when>
                                    </xsl:choose>
                                </xsl:when>
                            </xsl:choose>
                            <!-- When at least 1 required, test for siblings, if no siblings do not have delete -->
                        </xsl:when>
                        <xsl:otherwise>
                            <xf:trigger appearance="minimal" class="btn remove inline">
                                <xf:label/>
                                <xf:delete ev:event="DOMActivate" ref="."/>
                            </xf:trigger>
                        </xsl:otherwise>
                    </xsl:choose>
                    <xsl:choose>
                        <xsl:when test="$maxOccur">
                            <!-- Test if unbounded, if yes, have add, no restrictions -->
                            <xsl:choose>
                                <xsl:when test="$maxOccur castable as xs:integer">
                                    <xsl:choose>
                                        <xsl:when test="xs:integer($maxOccur) = 1">
                                            <!-- If one is required allow delete only if sibling elements exist -->
                                            <xf:trigger appearance="minimal" class="btn remove inline" ref="instance('i-rec')/{$path}[1]">
                                                <xf:label/>
                                                <xf:insert ev:event="DOMActivate" nodeset="instance('i-rec')/{$path}" at="last()" origin="instance('i-template')/{$path}[1]"/>
                                            </xf:trigger>
                                        </xsl:when>
                                        <xsl:when test="xs:integer($maxOccur) gt 1">
                                            <!-- WS:Note should find limit and bind ref to # of siblings -->
                                            <xf:trigger class="btn add inline" appearance="minimal" ref="instance('i-rec')/{$path}[1]">
                                                <xf:label/>
                                                <xf:insert ev:event="DOMActivate" nodeset="instance('i-rec')/{$path}" at="last()" origin="instance('i-template')/{$path}[1]"/>        
                                            </xf:trigger>
                                        </xsl:when>
                                    </xsl:choose>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xf:trigger class="btn add inline" appearance="minimal" ref="instance('i-rec')/{$path}[1]">
                                        <xf:label/>
                                        <xf:insert ev:event="DOMActivate" nodeset="instance('i-rec')/{$path}" at="last()" origin="instance('i-template')/{$path}[1]"/>        
                                    </xf:trigger>
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:when>
                        <xsl:otherwise>
                            <xf:trigger class="btn add inline" appearance="minimal" ref="instance('i-rec')/{$path}[1]">
                                <xf:label/>
                                <xf:insert ev:event="DOMActivate" nodeset="instance('i-rec')/{$path}" at="last()" origin="instance('i-template')/{$path}[1]"/>        
                            </xf:trigger>
                        </xsl:otherwise>
                    </xsl:choose>
                    <h4 class="inline">                    
                        <xsl:value-of select="$elementName"/>
                    </h4>
                </div>
                <xsl:if test="$elementRules/descendant::tei:attList">
                    <xsl:for-each-group select="$elementRules/descendant::tei:attList/descendant-or-self::tei:attDef" group-by="@ident">
                        <!-- 
                            Check if controlled value list, use select1 
                            otherwise use input
                            
                            Deal with adding global attributes or attribute groups
                            then have add/delete triggers
                        -->
                        <xsl:variable name="attRef" select="concat('@',current-grouping-key())"/>
                        <xsl:choose>
                            <xsl:when test="descendant-or-self::tei:valItem">
                                <!-- Controlled list -->
                                <xf:select1 ref="{$attRef}">
                                    <xf:label><xsl:value-of select="$attRef"/></xf:label>
                                    <xf:item>
                                        <xf:label>--- Select ---</xf:label>
                                        <xf:value/>
                                    </xf:item>
                                    <xf:itemset ref="instance('i-ctr-vals')//tei:{$elementName}/tei:{$attRef}/descendant::tei:valItem">
                                        <xf:label ref="@ident"/>
                                        <xf:value ref="@ident"/>
                                    </xf:itemset>
                                </xf:select1>
                                <xf:trigger appearance="minimal" class="btn remove pull-right" ref="{$attRef}">
                                    <xf:label/>
                                    <xf:delete ev:event="DOMActivate" ref="."/>
                                </xf:trigger>
                            </xsl:when>
                            <xsl:otherwise>
                                <xf:input ref="{$attRef}"/>
                                <xf:trigger appearance="minimal" class="btn remove pull-right" ref="{$attRef}">
                                    <xf:label/>
                                    <xf:delete ev:event="DOMActivate" ref="."/>
                                </xf:trigger>
                            </xsl:otherwise>
                        </xsl:choose>
                        <p><xsl:value-of select="@ident"/></p>
                    </xsl:for-each-group>
                </xsl:if>
                <xsl:if test="$elementRules/descendant::tei:content/tei:textNode or $elementRules/descendant::tei:content/tei:alternate/descendant::tei:textNode or not($elementRules//tei:elementSpec/tei:content/descendant-or-self::tei:elementRef)">
                    <!-- Text area -->        
                    <p>Text area</p>
                </xsl:if>
                <xsl:if test="$elementRules">
                    <xsl:for-each-group select="$elementRules//tei:elementSpec/tei:content/descendant-or-self::tei:elementRef" group-by="@key">
                        <xsl:if test="$elementName != @key">
                            <xsl:call-template name="xformElementUI">
                                <xsl:with-param name="elementName" select="@key"/>
                                <xsl:with-param name="path" select="$path"/>
                                <xsl:with-param name="min">    
                                    <xsl:if test="@minOccurs != ''"><xsl:value-of select="@minOccurs"/></xsl:if>
                                </xsl:with-param>
                                <xsl:with-param name="max">
                                    <xsl:if test="@maxOccurs != ''"><xsl:value-of select="@maxOccurs"/></xsl:if>
                                </xsl:with-param> 
                            </xsl:call-template>
                        </xsl:if>
                    </xsl:for-each-group>
                </xsl:if>
            </xsl:element>
        </div>
    </xsl:template>
    <!-- May not need this -->
    <xsl:template match="*" mode="formElementChild">
        <!-- WS: there is an endlessly nesting idno  -->
        <xsl:variable name="elementName" select="local-name(.)"/>
        <xsl:variable name="parentElementName" select="local-name(parent::*[1])"/>
        <xsl:variable name="parentElementRules">
            <xsl:for-each select="$localSchemaDoc//descendant-or-self::tei:elementSpec[@ident=$parentElementName]">
                <xsl:copy-of select="."/>
            </xsl:for-each>
        </xsl:variable>
        <xsl:variable name="localElementRules">
            <xsl:for-each select="$localSchemaDoc//descendant-or-self::*:elementSpec[@ident=$elementName]">
                <xsl:copy-of select="."/>
            </xsl:for-each>
        </xsl:variable>
        <xsl:variable name="globalElementRules">
            <xsl:for-each select="$globalSchemaDoc//descendant-or-self::*:elementSpec[@ident=$elementName]">
                <xsl:copy-of select="."/>
            </xsl:for-each>
        </xsl:variable>
        <div style="border:1px solid grey; padding:2px;">
            <xsl:variable name="path" select="replace(replace(replace(replace(path(.),'Q\{http://www.tei-c.org/ns/1.0\}','tei:'),'tei:TEI','/'),'\[[0-9]+\]',''),'///','//')"/>
            <xsl:variable name="xformsElement">
                <xsl:choose>
                    <xsl:when test="$parentElementRules/descendant::tei:elementRef[@key=$elementName][@maxOccurs='unbounded']">repeat</xsl:when>
                    <xsl:otherwise>group</xsl:otherwise>
                </xsl:choose>
            </xsl:variable>
            <xsl:variable name="availableChildren">
                <!-- Still need to handle classRefs -->
                <xsl:variable name="globalElements" select="$globalElementRules/descendant-or-self::*:content/descendant::*:elementRef/@key"/>
                <xsl:variable name="localElements" select="$localElementRules/descendant-or-self::*:content/descendant::*:elementRef/@key"/>
                <xsl:for-each-group select="$globalElements | $localElements" group-by=".">
                    <xsl:sort select="."/>
                    <xsl:element name="{.}" namespace="http://www.tei-c.org/ns/1.0"/>
                </xsl:for-each-group>
            </xsl:variable>
            <xsl:variable name="availableAttributes">
                <!-- in process -->
            </xsl:variable>
            <xsl:element name="{$xformsElement}" namespace="http://www.w3.org/2002/xforms">
                <xsl:variable name="elementRef">instance('i-rec')/<xsl:value-of select="$path"/></xsl:variable>
                <xsl:attribute name="ref" select="$elementRef"/>
                <xsl:attribute name="id" select="generate-id(.)"/>
                <xsl:attribute name="class">xformsGroup</xsl:attribute>
                <div class="inlineBlock">
                    <xsl:if test="not(child::element())">
                        <xf:trigger appearance="minimal" class="btn remove inline">
                            <xf:label/>
                            <xf:delete ev:event="DOMActivate" ref="."/>
                        </xf:trigger>
                        <xf:trigger class="btn add inline" appearance="minimal" ref="instance('i-rec')/{$path}[1]">
                            <xf:label/>
                            <xf:insert ev:event="DOMActivate" nodeset="instance('i-rec')/{$path}" at="last()" origin="instance('i-template')/{$path}[1]"/>    
                        </xf:trigger>
                    </xsl:if>
                    <h4 class="inline">                    
                        <xsl:value-of select="$elementName"/>
                    </h4>
                    <!--                    <xsl:sequence select="$availableChildren"></xsl:sequence>-->
                    <xsl:if test="$availableChildren/element()">
                        <!-- WS:NOTE find full element in elements instance (generate based on schema? ugh)  -->
                        <xf:select1 ref="instance('i-insert-elements')//tei:element">
                            <xf:label>Available Elements</xf:label>
                            <xsl:for-each select="$availableChildren/element()">
                                <xf:item>
                                    <xf:label><xsl:value-of select="local-name(.)"/></xf:label>
                                    <xf:value><xsl:value-of select="local-name(.)"/></xf:value> 
                                </xf:item>
                            </xsl:for-each>
                            <!-- Insert selected element -->
                            <xf:action ev:event="xforms-value-changed">
                                <xf:insert
                                    context="{$elementRef}"
                                    at="last()" position="after"
                                    origin="instance('i-elementTemplate')//*[local-name(.) = instance('i-insert-elements')//tei:element]"/>
                                <xf:setvalue ref="instance('i-insert-elements')//tei:element" value="''"/>
                            </xf:action>
                        </xf:select1>
                    </xsl:if>
                    <xsl:if test="$availableAttributes != ''">
                        <xf:select1 ref="instance('i-insert-attributes')//tei:attribute">
                            <xf:label>Available Attributes</xf:label>
                            <xsl:sequence select="$availableAttributes"/>
                            <!-- Insert selected element -->
                            <xf:action ev:event="xforms-value-changed">
                                <xf:insert
                                    context="{$elementRef}"
                                    at="last()" position="after"
                                    origin="instance('i-attributeTemplate')//@*[local-name(.) = instance('i-insert-attributes')//tei:attribute]"/>
                                <xf:setvalue ref="instance('i-insert-attributes')//tei:attribute" value="''"/>
                            </xf:action>
                        </xf:select1>
                    </xsl:if>
                </div>
                <xsl:if test="not(child::element())">
                    <xsl:choose>
                        <xsl:when test="$elementName = 'p' or $elementName = 'desc'">
                            <xf:textarea ref=".">
                                <xf:label><xsl:value-of select="$elementName"/></xf:label>
                            </xf:textarea>
                        </xsl:when>
                        <xsl:otherwise>
                            <xf:input ref=".">
                                <xf:label><xsl:value-of select="$elementName"/></xf:label>
                            </xf:input>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:if>
                <xsl:for-each select="@*">
                    <div class="btn-group" style="border:1px solid #eee;">
                        <xsl:choose>
                            <xsl:when test="$localElementRules/descendant::tei:attDef[@ident=local-name(.)]/tei:valList">
                                <xf:select1 ref="{concat('@',name(.))}">
                                    <xf:label><xsl:value-of select="name(.)"/></xf:label>
                                    <xf:item>
                                        <xf:label>--- Select ---</xf:label>
                                        <xf:value/>
                                    </xf:item>
                                    <xf:itemset ref="instance('i-ctr-vals')//tei:{$elementName}/tei:{local-name(.)}/descendant::tei:valItem">
                                        <xf:label ref="@ident"/>
                                        <xf:value ref="@ident"/>
                                    </xf:itemset>
                                </xf:select1>
                            </xsl:when>
                            <xsl:otherwise>
                                <xf:input ref="{concat('@',name(.))}">
                                    <xf:label><xsl:value-of select="name(.)"/></xf:label>
                                </xf:input>
                            </xsl:otherwise>
                        </xsl:choose>
                        <xf:trigger appearance="minimal" class="btn remove pull-right" ref="{concat('@',name(.))}">
                            <xf:label/>
                            <xf:delete ev:event="DOMActivate" ref="."/>
                        </xf:trigger>
                    </div>
                </xsl:for-each>
                <xsl:for-each select="$localElementRules/descendant::tei:attDef">
                    <!-- Add new attribute, from where??  -->
                    <!-- NOTE: add a template for each element, construct element with all optional attributes and children?  -->
                    <xsl:variable name="attName" select="@ident"/>
                    <xsl:choose>
                        <!-- When already in template,ignore, otherwise add an input or select -->
                        <!-- @*/name() = $names -->
                        <xsl:when test="@*/name() = $attName"/>
                        <xsl:otherwise>
                            <div class="btn-group" style="border:1px solid #eee;">
                                <xsl:choose>
                                    <xsl:when test="tei:valList">
                                        <xf:select1 ref="{concat('@',$attName)}">
                                            <xf:label><xsl:value-of select="$attName"/></xf:label>
                                            <xf:item>
                                                <xf:label>--- Select ---</xf:label>
                                                <xf:value/>
                                            </xf:item>
                                            <xf:itemset ref="instance('i-ctr-vals')//tei:{$elementName}/tei:{$attName}/descendant::tei:valItem">
                                                <xf:label ref="@ident"/>
                                                <xf:value ref="@ident"/>
                                            </xf:itemset>
                                            <!--
                                            <xsl:for-each select="tei:valList/tei:valItem">
                                                <xf:item>
                                                    <xf:label ref="@ident"/>
                                                    <xf:value ref="@ident"/>
                                                </xf:item> 
                                            </xsl:for-each>
                                            -->
                                        </xf:select1>
                                    </xsl:when>
                                    <xsl:otherwise>
                                        <xf:input ref="{concat('@',$attName)}">
                                            <xf:label><xsl:value-of select="$attName"/></xf:label>
                                        </xf:input>
                                    </xsl:otherwise>
                                </xsl:choose>
                                <xf:trigger appearance="minimal" class="btn remove pull-right" ref="{concat('@',$attName)}">
                                    <xf:label/>
                                    <xf:delete ev:event="DOMActivate" ref="."/>
                                </xf:trigger>
                            </div>
                        </xsl:otherwise>
                    </xsl:choose>
                    <xf:trigger class="btn add" appearance="minimal" ref="self::node()[not({concat('@',$attName)})]">
                        <xf:label>Add <xsl:value-of select="@ident"/></xf:label>
                        <xf:insert ev:event="DOMActivate" context="." at="." origin="instance('i-template')//tei:{$elementName}/@{@ident}"/>    
                    </xf:trigger>
                </xsl:for-each>
            </xsl:element>
        </div>
    </xsl:template>
    <!-- <xsl:apply-templates select="." mode="formElement"/> -->
    <xsl:template match="*" mode="formRules">
        <!-- Place Holder -->
    </xsl:template>
    <!-- named templates used to build a full example template to pull optional attributes and elements from. Based on Local Schema first, then main schema -->
    <xsl:template name="elementTemplate">
        <TEI xmlns="http://www.tei-c.org/ns/1.0">
            <!-- get available children, and order them correctly, add unbound or min max occurance attributes, maybe?  -->
            
            <xsl:call-template name="buildElement">
                <xsl:with-param name="elementName" select="'teiHeader'"/>        
            </xsl:call-template>
        
            <xsl:call-template name="buildElement">
                <xsl:with-param name="elementName" select="'text'"/>     
            </xsl:call-template>
        
            <!-- Go through global schema, output one of every element -->
            <!-- Troubleshooting
            <div class="globalInfo">
                <xsl:value-of select="count($globalSchemaDoc//tei:elementSpec)"/>
            </div>
            <div class="localInfo">
                <xsl:value-of select="count($localSchemaDoc//tei:elementSpec)"/>
            </div> -->
            <!-- 
            <xsl:for-each select="$globalSchemaDoc//tei:elementSpec">
                <xsl:sort select="@ident" order="ascending"/>
                <xsl:variable name="elementName" select="@ident"/>
                <xsl:element name="{$elementName}" namespace="http://www.tei-c.org/ns/1.0"/>
            </xsl:for-each>
            -->
        </TEI>
    </xsl:template>
    <xsl:template name="buildElement">
        <xsl:param name="elementName"/>
        <!-- 
            <attributes>
                <xsl:for-each select="local:availableAttributes($elementName)">
                    <att><xsl:value-of select="local-name(.)"/></att>
                </xsl:for-each>
            </attributes>
            -->
        <xsl:element name="{$elementName}" namespace="http://www.tei-c.org/ns/1.0">
                <xsl:for-each select="local:availableChildren($elementName)">
                        <xsl:choose>
                            <xsl:when test="local-name(.) = $elementName"/>
                            <xsl:otherwise>
                                <xsl:call-template name="buildElement">
                                    <xsl:with-param name="elementName" select="local-name(.)"/>
                                </xsl:call-template>
                            </xsl:otherwise>
                        </xsl:choose>
                </xsl:for-each>
            
            <!--
            <xsl:for-each select="$availableChildren">
                <xsl:call-template name="buildElement"/>
            </xsl:for-each>
            -->
        </xsl:element>
    </xsl:template>
    <xsl:template name="attributesTemplate">
        <TEI xmlns="http://www.tei-c.org/ns/1.0">
            <element>
                <!-- Go through global and local schema, output one of every attribute -->
                <xsl:for-each-group select="$globalSchemaDoc//tei:attDef | $localSchemaDoc//tei:attDef" group-by="@ident">
                    <xsl:sort select="@ident" order="ascending"/>
                    <xsl:variable name="attName" select="@ident"/>
                    <xsl:attribute name="{$attName}"/>
                </xsl:for-each-group>  
            </element>
        </TEI>
    </xsl:template>
    
</xsl:stylesheet>