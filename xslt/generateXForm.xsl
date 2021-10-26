<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet 
    xmlns="http://www.w3.org/1999/xhtml" 
    xmlns:tei="http://www.tei-c.org/ns/1.0" 
    xmlns:sc="http://www.ascc.net/xml/schematron" 
    xmlns:xf="http://www.w3.org/2002/xforms"
    xmlns:ev="http://www.w3.org/2001/xml-events"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" 
    xmlns:xi="http://www.w3.org/2001/XInclude"
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
    <!-- app root -->
    <xsl:variable name="app-root" select="'http://localhost:8080/exist/apps/mssXForms/forms'"/>
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
        <xsl:variable name="localRules">
            <xsl:for-each select="$localSchemaDoc//descendant-or-self::tei:elementSpec[@ident=$elementName]">
                <xsl:copy-of select="."/>
            </xsl:for-each>
        </xsl:variable>
        <rules xmlns="http://www.tei-c.org/ns/1.0">
            <local>
                <xsl:copy-of select="$localRules"/>
            </local>
            <global>
                <xsl:choose>
                    <xsl:when test="$localRules/child::*">
                        <xsl:choose>
                            <xsl:when test="$localRules/descendant-or-self::*[@mode='replace'] | $localRules/descendant-or-self::*[@mode='add'] | $localRules/descendant-or-self::*[@mode='change']"/>
                            <xsl:otherwise>
                                <xsl:for-each select="$globalSchemaDoc//descendant-or-self::tei:elementSpec[@ident=$elementName]">
                                    <xsl:copy-of select="."/>
                                </xsl:for-each>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:for-each select="$globalSchemaDoc//descendant-or-self::tei:elementSpec[@ident=$elementName]">
                            <xsl:copy-of select="."/>
                        </xsl:for-each>
                    </xsl:otherwise>
                </xsl:choose>
            </global> 
        </rules>
    </xsl:function>
    
    <xsl:function name="local:resolveElementClassRef">
        <xsl:param name="className"/>
        <xsl:variable name="localClass">
            <xsl:for-each select="$localSchemaDoc//descendant-or-self::*[tei:classes/tei:memberOf[@key=$className]]">
                <xsl:choose>
                    <xsl:when test="self::tei:elementSpec">
                        <element ident="{string(@ident)}"><xsl:value-of select="string(@ident)"/></element>
                    </xsl:when>
                    <xsl:when test="self::tei:classSpec">
                        <xsl:variable name="subClassName" select="@ident"/>
                        <xsl:copy-of select="local:resolveElementClassRef($subClassName)"/>
                    </xsl:when>
                </xsl:choose>
            </xsl:for-each>
        </xsl:variable>
        <xsl:choose>
            <xsl:when test="$localClass//*:element"><xsl:copy-of select="$localClass"/></xsl:when>
            <xsl:otherwise>
                <xsl:for-each select="$globalSchemaDoc//descendant-or-self::*[tei:classes/tei:memberOf[@key=$className]]">
                    <xsl:choose>
                        <xsl:when test="self::tei:elementSpec">
                            <element ident="{string(@ident)}"><xsl:value-of select="string(@ident)"/></element>
                        </xsl:when>
                        <xsl:when test="self::tei:classSpec">
                            <xsl:variable name="subClassName" select="@ident"/>
                            <xsl:copy-of select="local:resolveElementClassRef($subClassName)"/>
                        </xsl:when>
                    </xsl:choose>
                </xsl:for-each>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>
    <xsl:function name="local:elementRefs">
        <xsl:param name="elementName"/>
        <xsl:variable name="elementRules" select="local:elementRules($elementName)"/>
        <xsl:variable name="childElement" select="$elementRules/descendant-or-self::tei:elementRef | $elementRules/descendant-or-self::tei:classRef"/>
        <xsl:for-each-group select="$childElement" group-by="@key">
            <element ident="{string(current-grouping-key())}"><xsl:copy-of select="@*"/>
                <xsl:choose>
                    <xsl:when test="self::tei:classRef">
                        <xsl:attribute name="classRef" select="'true'"/>
                        <xsl:copy-of select="local:resolveElementClassRef(current-grouping-key())"/>
                    </xsl:when>
                    <xsl:otherwise><xsl:value-of select="current-grouping-key()"/></xsl:otherwise>
                </xsl:choose>
            </element>
        </xsl:for-each-group>
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
    <xsl:function name="local:childAttributes">
        <xsl:param name="elementName"/>
        <xsl:variable name="elementRules" select="local:elementRules($elementName)"/>
        <xsl:variable name="childAtt" select="$elementRules/descendant-or-self::tei:attList/descendant-or-self::tei:attDef"/>
        <xsl:for-each-group select="$childAtt" group-by="@ident">
            <xsl:copy-of select="."></xsl:copy-of>
        </xsl:for-each-group>
    </xsl:function>
    <xsl:function name="local:referencedAttributeGroups">
        <xsl:param name="elementName"/>
        <xsl:variable name="elementRules" select="local:elementRules($elementName)"/>
        <xsl:variable name="memberOf" select="$elementRules/descendant-or-self::tei:classes/tei:memberOf[starts-with(@key,'att.')]/@key"/>
        <xsl:variable name="classRef" select="$elementRules/descendant-or-self::tei:classRef[starts-with(@key,'att.')]/@key"/>
        <xsl:variable name="memberOfRules" select="local:elementRules($memberOf)/descendant-or-self::tei:attList/descendant-or-self::tei:attDef"/>
        <xsl:variable name="classRefRules" select="local:elementRules($classRef)/descendant-or-self::tei:attList/descendant-or-self::tei:attDef"/>
        <xsl:for-each-group select="$memberOfRules | $classRefRules" group-by="@ident">
            <xsl:copy-of select="."></xsl:copy-of>
        </xsl:for-each-group>
    </xsl:function>
    <xsl:function name="local:allAttributes">
        <xsl:param name="elementName"/>
        <xsl:variable name="elementRules" select="local:elementRules($elementName)"/>
        <xsl:variable name="childAtt" select="$elementRules/descendant-or-self::tei:attList/descendant-or-self::tei:attDef"/>
        <xsl:variable name="memberOf" select="$elementRules/descendant-or-self::tei:classes/tei:memberOf[starts-with(@key,'att.')]/@key"/>
        <xsl:variable name="classRef" select="$elementRules/descendant-or-self::tei:classRef[starts-with(@key,'att.')]/@key"/>
        <xsl:variable name="memberOfRules" select="local:elementRules($memberOf)/descendant-or-self::tei:attList/descendant-or-self::tei:attDef"/>
        <xsl:variable name="classRefRules" select="local:elementRules($classRef)/descendant-or-self::tei:attList/descendant-or-self::tei:attDef"/>
        <xsl:for-each-group select="local:referencedAttributeGroups($elementName) | local:childAttributes($elementName)" group-by="@ident">
            <xsl:copy-of select="."></xsl:copy-of>
        </xsl:for-each-group>
    </xsl:function>
    

    <!-- 
        Steps: 
        Generate controlled values
        genreate attributes
        generate reuseable elements/attributes
        generate xf:bind rules based on schema
        generate instances 
        
    -->
    
    <xsl:template match="/">
        <!-- Output XForm for each subform in config.xml, if no subforms, output full TEI record (not recommended). -->
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
        <!-- Output reusable form elements -->
        <!-- classSpec xmlns:xi="http://www.w3.org/2001/XInclude" module="tei" type="atts" -->
        <xsl:for-each-group select="$localSchemaDoc//tei:classSpec[@type='atts'] | $globalSchemaDoc//tei:classSpec[@type='atts']" group-by="@ident">
            <xsl:variable name="attName" select="current-grouping-key()"/>
            <xsl:result-document href="subforms/attributes/{$attName}UI.xhtml" format="xform">
                <div xmlns="http://www.w3.org/1999/xhtml" xmlns:ev="http://www.w3.org/2001/xml-events" xmlns:xf="http://www.w3.org/2002/xforms">
                    <xsl:call-template name="attributeUI">
                        <xsl:with-param name="attName" select="$attName"/>
                    </xsl:call-template>
                </div>
            </xsl:result-document>
        </xsl:for-each-group>
        <xsl:for-each-group select="$globalSchemaDoc//tei:elementSpec" group-by="@ident">
            <xsl:variable name="elementName" select="current-grouping-key()"/>
            <xsl:result-document href="subforms/elements/{$elementName}UI.xhtml" format="xform">
            <xsl:choose>
                <xsl:when test="$localSchemaDoc//tei:elementSpec[@ident = $elementName]">
                    <xsl:for-each-group select="$localSchemaDoc//tei:elementSpec[@ident = $elementName]" group-by="@ident">  
                        <div xmlns="http://www.w3.org/1999/xhtml" xmlns:ev="http://www.w3.org/2001/xml-events" xmlns:xf="http://www.w3.org/2002/xforms">
                            <xsl:call-template name="elementUI">
                                <xsl:with-param name="elementName" select="$elementName"/>
                            </xsl:call-template>
                        </div>
                    </xsl:for-each-group>
                </xsl:when>
                <xsl:otherwise>
                    <div xmlns="http://www.w3.org/1999/xhtml" xmlns:ev="http://www.w3.org/2001/xml-events" xmlns:xf="http://www.w3.org/2002/xforms">
                        <xsl:call-template name="elementUI">
                            <xsl:with-param name="elementName" select="$elementName"/>
                        </xsl:call-template>    
                    </div>
                </xsl:otherwise>
            </xsl:choose>
            </xsl:result-document>
        </xsl:for-each-group>
        <!-- <attDef ident="anchored" usage="opt"> -->
    </xsl:template>
    <xsl:template name="xform">
        <xsl:param name="subform"/>
                <xsl:text disable-output-escaping='yes'>&lt;!DOCTYPE html&gt;</xsl:text>
                <html xmlns="http://www.w3.org/1999/xhtml" 
                    xmlns:xi="http://www.w3.org/2001/XInclude"
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
                            <xf:instance xmlns="http://www.tei-c.org/ns/1.0" id="i-attributeTemplate" src="forms/templates/attributesTemplate.xml"/>
                            <!-- i-insert-elements -->
                            <xf:instance xmlns="http://www.tei-c.org/ns/1.0" id="i-insert-elements">
                                <TEI><element></element></TEI>
                            </xf:instance>
                            <xf:instance xmlns="http://www.tei-c.org/ns/1.0" id="i-insert-attributes">
                                <TEI><attribute></attribute></TEI>
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
                                    <xsl:with-param name="level" select="'root'"/>
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
        <!-- Build a template with all possible child elements and attributes, referenced by the xforms model -->
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
    <xsl:template name="xformElementUItest">
        <xsl:param name="elementName"/>
        <xsl:param name="path"/>
        <xsl:param name="min"/>
        <xsl:param name="max"/>   
        <xsl:param name="level"/>   
        
        <xsl:variable name="elementRules" select="local:elementRules($elementName)"/>
        <xsl:variable name="referencedAttributeGroups" select="local:referencedAttributeGroups($elementName)"/>
        <xsl:variable name="childAttributes" select="local:childAttributes($elementName)"/>
        <xsl:variable name="allAttributes" select="local:allAttributes($elementName)"/>
        <xsl:variable name="path" select="concat($path,'/tei:',$elementName)"/>
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
        <div style="border:1px solid grey; padding-left:1em;">
            <p><xsl:value-of select="$elementName"/></p>
            <xsl:variable name="childElements" select="local:elementRefs($elementName)"/>
            <div>
                <xsl:for-each-group select="$childElements/descendant-or-self::*:element[not(@classRef='true')]" group-by="@ident">
                    <xsl:copy-of select="."/>
                </xsl:for-each-group>
            </div>
            <!--
            <p>direct ref children</p>
            <ul>
                <xsl:for-each-group select="$elementRules/descendant-or-self::tei:content/descendant::tei:elementRef" group-by="@key">
                    <li><xsl:value-of select="current-grouping-key()"/></li>
                </xsl:for-each-group>     
            </ul>
            <p>class ref children</p>
            <ul>
                <xsl:for-each-group select="$elementRules/descendant-or-self::tei:content/descendant::tei:classRef[starts-with(@key,'model.')]" group-by="@key">
                    <li>
                        <xsl:value-of select="current-grouping-key()"/>
                        <xsl:variable name="childElementRules" select="local:elementRules(current-grouping-key())"/>
                        <xsl:choose>
                            <xsl:when test="$childElementRules/descendant::tei:elementSpec">
                                <ul>
                                    <xsl:for-each-group select="$childElementRules/descendant-or-self::tei:content/descendant::tei:elementRef" group-by="@key">
                                        <li><xsl:value-of select="current-grouping-key()"/></li>
                                    </xsl:for-each-group>    
                                </ul>
                            </xsl:when>
                            <xsl:when test="$localSchemaDoc//descendant-or-self::tei:elementSpec[tei:classes/tei:memberOf[@key=current-grouping-key()]]">
                                
                                <xsl:for-each select="$localSchemaDoc//descendant-or-self::tei:elementSpec[tei:classes/tei:memberOf[@key=current-grouping-key()]]">
                                    <element ident="{string(@ident)}"><xsl:copy-of select="$elementRules/@*"></xsl:copy-of><xsl:value-of select="string(@ident)"/></element>
                                </xsl:for-each>
                            </xsl:when>
                            <xsl:when test="$globalSchemaDoc//descendant-or-self::tei:elementSpec[tei:classes/tei:memberOf[@key=current-grouping-key()]]">
                                <xsl:for-each select="$globalSchemaDoc//descendant-or-self::tei:elementSpec[tei:classes/tei:memberOf[@key=current-grouping-key()]]">
                                    <element ident="{string(@ident)}"><xsl:copy-of select="$elementRules/@*"></xsl:copy-of><xsl:value-of select="string(@ident)"/></element>
                                </xsl:for-each>
                            </xsl:when>
                            <xsl:otherwise>
                                False:
                            </xsl:otherwise>
                        </xsl:choose>
                    </li>
                </xsl:for-each-group>     
            </ul>
               -->
            
        </div>
    </xsl:template>

    <!-- named templates used to build a full example template to pull optional attributes and elements from. Based on Local Schema first, then main schema -->
    <xsl:template name="elementTemplate">
        <TEI xmlns="http://www.tei-c.org/ns/1.0">
            <xsl:variable name="teiHeaderElements" select="local:elementRules('teiHeader')"/>
            <xsl:variable name="textElements" select="local:elementRules('text')"/>
            <xsl:for-each-group select="$localSchemaDoc//descendant-or-self::tei:elementSpec | $globalSchemaDoc//descendant-or-self::tei:elementSpec" group-by="@ident">
                <xsl:sort select="current-grouping-key()"/>
                <xsl:element name="{current-grouping-key()}" namespace="http://www.tei-c.org/ns/1.0"/>
            </xsl:for-each-group>
            <!--WS:Note 
                This works, but it since it has all the children, whenever you insert an element, it insert the element and available children, 
                I think what we want is a flat output of all available elements, not necessarily nested, just a list. 
            
            <xsl:for-each select="$configDoc//subform">
                <xsl:call-template name="buildElementInstance">
                    <xsl:with-param name="elementName" select="@formName"/>     
                </xsl:call-template>
            </xsl:for-each>
            -->
        </TEI>
    </xsl:template>
    <!-- WS:Note - not currently used -->
    <xsl:template name="buildElementInstance">
        <xsl:param name="elementName"/>
        <xsl:variable name="elementRules" select="local:elementRules($elementName)"/>
        <xsl:element name="{$elementName}" namespace="http://www.tei-c.org/ns/1.0">
            <xsl:for-each-group select="$elementRules//tei:elementSpec/tei:content/descendant-or-self::tei:elementRef" group-by="@key">
                <xsl:choose>
                    <xsl:when test="@key = $elementName"/>
                    <xsl:otherwise>
                        <xsl:call-template name="buildElementInstance">
                            <xsl:with-param name="elementName" select="@key"/>
                        </xsl:call-template>
                    </xsl:otherwise>
                </xsl:choose>    
            </xsl:for-each-group>
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
    <xsl:template name="attributeUI">
        <xsl:param name="attName"/>
        <xsl:for-each-group select="descendant::tei:attDef" group-by="@ident">
            <xsl:variable name="attDefName" select="current-grouping-key()"/>
            <xsl:variable name="attDefPath" select="concat('@',$attDefName)"/>
            <xsl:choose>
                <xsl:when test="descendant-or-self::tei:valItem">
                    <span class="attribute-group">
                        <xf:select1 ref="{$attDefPath}" xmlns="http://www.w3.org/2002/xforms">
                            <xf:label><xsl:value-of select="$attDefName"/></xf:label>
                            <xf:item>
                                <xf:label> Select </xf:label>
                                <xf:value/>
                            </xf:item>
                            <xsl:for-each select="descendant-or-self::tei:valItem">
                                <xf:item>
                                    <xf:label><xsl:value-of select="@ident"/></xf:label>
                                    <xf:value><xsl:value-of select="@ident"/></xf:value>
                                </xf:item>
                            </xsl:for-each>
                        </xf:select1>
                        <xf:trigger appearance="minimal" class="btn remove" ref="{$attDefPath}">
                            <xf:label/>
                            <xf:delete ev:event="DOMActivate" ref="."/>
                        </xf:trigger>
                    </span>
                </xsl:when>
                <xsl:otherwise>
                    <span class="attribute-group"> 
                        <xf:input ref="{$attDefPath}">
                            <xf:label><xsl:value-of select="$attDefName"/></xf:label>    
                        </xf:input>
                        <xf:trigger appearance="minimal" class="btn remove" ref="{$attDefPath}">
                            <xf:label/>
                            <xf:delete ev:event="DOMActivate" ref="."/>
                        </xf:trigger>
                    </span>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:for-each-group>
    </xsl:template>
    
    <xsl:template name="elementUI">
        <xsl:param name="elementName"/>  
        <!-- element variables -->
        <xsl:variable name="elementRules" select="local:elementRules($elementName)"/>
        <xsl:variable name="referencedAttributeGroups" select="local:referencedAttributeGroups($elementName)"/>
        <xsl:variable name="childAttributes" select="local:childAttributes($elementName)"/>
        <xsl:variable name="allAttributes" select="local:allAttributes($elementName)"/>
        <xsl:variable name="childElements" select="local:elementRefs($elementName)"/>
        
        <xsl:variable name="xformsElement">repeat</xsl:variable>
        <xsl:element name="{$xformsElement}" namespace="http://www.w3.org/2002/xforms">
            <xsl:variable name="elementRef"><xsl:value-of select="concat('tei:',$elementName)"/></xsl:variable>
            <xsl:attribute name="ref" select="$elementRef"/>
<!--            <xsl:attribute name="id" select="generate-id(.)"/>-->
            <xsl:attribute name="class">xformsGroup</xsl:attribute>
            <div style="border:1px solid grey; padding:4px;">
                <div class="inlineBlock">
                    <!--
                    <xsl:choose>
                        <xsl:when test="$minOccur">
                            <xsl:choose>
                                <xsl:when test="$minOccur castable as xs:integer">
                                    <xsl:choose>
                                        <xsl:when test="xs:integer($minOccur) lt 1">
                                            <xf:trigger appearance="minimal" class="btn remove inline" xmlns="http://www.w3.org/2002/xforms">
                                                <xf:label/>
                                                <xf:delete ev:event="DOMActivate" ref="."/>
                                            </xf:trigger>
                                        </xsl:when>
                                        <xsl:when test="xs:integer($minOccur) = 1">
                                            <xf:trigger appearance="minimal" class="btn remove inline" ref=".[following-sibling::tei:{$elementName}]" xmlns="http://www.w3.org/2002/xforms">
                                                <xf:label/>
                                                <xf:delete ev:event="DOMActivate" ref="."/>
                                            </xf:trigger>
                                        </xsl:when>
                                        <xsl:when test="xs:integer($minOccur) gt 1">
                                            <xf:trigger appearance="minimal" class="btn remove inline" ref=".[following-sibling::tei:{$elementName}]" xmlns="http://www.w3.org/2002/xforms">
                                                <xf:label/>
                                                <xf:delete ev:event="DOMActivate" ref="."/>
                                            </xf:trigger>
                                        </xsl:when>
                                    </xsl:choose>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xf:trigger appearance="minimal" class="btn remove inline" xmlns="http://www.w3.org/2002/xforms">
                                        <xf:label/>
                                        <xf:delete ev:event="DOMActivate" ref="."/>
                                    </xf:trigger>
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:when>
                        <xsl:otherwise>
                            <xf:trigger appearance="minimal" class="btn remove inline" xmlns="http://www.w3.org/2002/xforms">
                                <xf:label/>
                                <xf:delete ev:event="DOMActivate" ref="."/>
                            </xf:trigger>
                        </xsl:otherwise>
                    </xsl:choose>
                    -->
                    <xf:trigger appearance="minimal" class="btn remove inline" xmlns="http://www.w3.org/2002/xforms">
                        <xf:label/>
                        <xf:delete ev:event="DOMActivate" ref="."/>
                    </xf:trigger>
                    <span class="elementLable {$xformsElement}"><xsl:value-of select="$elementName"/> | </span>
                    <xsl:if test="$allAttributes/descendant-or-self::tei:attDef">
                        <!-- maybe put rules for additional attr./elements here, not an add button?  -->
                        <xf:select1 ref="instance('i-insert-attributes')//tei:attribute">
                            <xf:label>Available Attributes</xf:label>
                            <xf:item>
                                <xf:label>--- Select ---</xf:label>
                                <xf:value/>
                            </xf:item>
                            <xsl:for-each-group select="$allAttributes/descendant-or-self::tei:attDef" group-by="@ident">
                                <xsl:sort select="current-grouping-key()"/>
                                <xf:item>
                                    <xf:label><xsl:value-of select="current-grouping-key()"/></xf:label>
                                    <xf:value><xsl:value-of select="current-grouping-key()"/></xf:value>
                                </xf:item>
                            </xsl:for-each-group>
                            <!--
                                <xf:action ev:event="xforms-value-changed">
                                    <xf:insert
                                        context="{$path}"
                                        origin="instance('i-attributeTemplate')//@*[local-name(.) = instance('i-insert-attributes')//tei:attribute]"/>
                                    <xf:setvalue ref="instance('i-insert-attributes')//tei:attribute" value="''"/>
                                </xf:action>
                                -->
                        </xf:select1>
                        <xf:trigger class="btn add" appearance="minimal" ref=".">
                            <xf:label>add attribute</xf:label>
                            <xf:insert ev:event="DOMActivate" context="." at="." origin="instance('i-attributeTemplate')//@*[name(.) = instance('i-insert-attributes')//tei:attribute]"/>
                            <xf:setvalue ref="instance('i-insert-attributes')//tei:attribute" value="''"/>
                        </xf:trigger>
                    </xsl:if>
                    <xsl:if test="$elementRules/descendant::tei:content/descendant-or-self::tei:elementRef or $elementRules/descendant::tei:content/descendant-or-self::tei:classRef">
                        <xf:select1 ref="instance('i-insert-elements')//tei:element">
                            <xf:label>Available Elements</xf:label>
                            <xf:item>
                                <xf:label> Select </xf:label>
                                <xf:value/>
                            </xf:item>
                            <xsl:for-each-group select="$childElements/descendant-or-self::*:element[not(@classRef='true')]" group-by="@ident">
                                <xsl:sort select="current-grouping-key()"/>
                                <xf:item>
                                    <xf:label><xsl:value-of select="current-grouping-key()"/></xf:label>
                                    <xf:value><xsl:value-of select="current-grouping-key()"/></xf:value>
                                </xf:item>
                            </xsl:for-each-group>
                        </xf:select1>
                        <xf:trigger class="btn add" appearance="minimal" ref=".">
                            <xf:label>add element</xf:label>
                            <xf:insert
                                context="{$elementRef}"
                                at="last()" position="after"
                                origin="instance('i-elementTemplate')//*[local-name(.) = instance('i-insert-elements')//tei:element]"/>
                            <xf:setvalue ref="instance('i-insert-elements')//tei:element" value="''"/>
                        </xf:trigger>
                    </xsl:if>
                </div>
                <xsl:if test="$childAttributes/descendant-or-self::tei:attDef">
                    <xsl:for-each-group select="$childAttributes/descendant-or-self::tei:attDef" group-by="@ident">
                        <!-- 
                                Check if controlled value list, use select1 
                                otherwise use input
                                
                                Deal with adding global attributes or attribute groups
                                Add for any that are not in current record
                            -->
                        <xsl:variable name="attRef" select="concat('@',current-grouping-key())"/>
                        <xsl:choose>
                            <xsl:when test="descendant-or-self::tei:valItem">
                                <!-- Controlled list - make sure controlled list matches the correct parent/parents-->
                                <span class="attribute-group">
                                    <xf:select1 ref="{$attRef}" xmlns="http://www.w3.org/2002/xforms">
                                        <xf:label><xsl:value-of select="current-grouping-key()"/></xf:label>
                                        <xf:item>
                                            <xf:label>--- Select ---</xf:label>
                                            <xf:value/>
                                        </xf:item>
                                        <xsl:for-each select="descendant-or-self::tei:valItem">
                                            <xf:item>
                                                <xf:label><xsl:value-of select="@ident"/></xf:label>
                                                <xf:value><xsl:value-of select="@ident"/></xf:value>
                                            </xf:item>
                                        </xsl:for-each>
                                    </xf:select1>
                                    <xf:trigger appearance="minimal" class="btn remove" ref="{$attRef}">
                                        <xf:label/>
                                        <xf:delete ev:event="DOMActivate" ref="."/>
                                    </xf:trigger>
                                </span>
                            </xsl:when>
                            <xsl:otherwise>
                                <span class="attribute-group"> 
                                    <xf:input ref="{$attRef}">
                                        <xf:label><xsl:value-of select="current-grouping-key()"/></xf:label>    
                                    </xf:input>
                                    <xf:trigger appearance="minimal" class="btn remove" ref="{$attRef}">
                                        <xf:label/>
                                        <xf:delete ev:event="DOMActivate" ref="."/>
                                    </xf:trigger>
                                </span>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:for-each-group>
                </xsl:if>
                <xsl:for-each-group select="$elementRules/descendant-or-self::tei:classes/tei:memberOf[starts-with(@key,'att.')] | $elementRules/descendant-or-self::tei:classRef[starts-with(@key,'att.')]" group-by="@key">
                    <xsl:variable name="attrSubformRef" select="concat($app-root,'/subforms/attributes/',current-grouping-key(),'UI.xhtml')"></xsl:variable>
                    <xi:include href="{$attrSubformRef}"></xi:include>
                </xsl:for-each-group>
                <xsl:if test="$elementRules/descendant::tei:content/descendant::tei:textNode or not($elementRules//tei:elementSpec/tei:content/descendant-or-self::tei:elementRef) or not($elementRules//tei:elementSpec/tei:content/descendant-or-self::tei:classRef)">
                    <!-- Text area --> 
                    <xsl:choose>
                        <xsl:when test="$elementName = 'p' or $elementName = 'desc'">
                            <xf:textarea ref="." xmlns="http://www.w3.org/2002/xforms">
                                <xf:label><xsl:value-of select="$elementName"/></xf:label>
                            </xf:textarea>
                        </xsl:when>
                        <xsl:otherwise>
                            <xf:input ref="." xmlns="http://www.w3.org/2002/xforms">
                                <xf:label><xsl:value-of select="$elementName"/></xf:label>
                            </xf:input>
                        </xsl:otherwise>
                    </xsl:choose>    
                </xsl:if> 
                <xsl:if test="$elementRules/descendant::tei:content/descendant-or-self::tei:elementRef or $elementRules/descendant::tei:content/descendant-or-self::tei:classRef">
                    <xsl:for-each-group select="$childElements/descendant-or-self::*:element[not(@classRef='true')]" group-by="@ident">
                        <xsl:if test="$elementName != current-grouping-key()">
                            <xsl:variable name="subformRef" select="concat($app-root,'/subforms/elements/',current-grouping-key(),'UI.xhtml')"></xsl:variable>
                            <xi:include href="{$subformRef}"></xi:include>
                        </xsl:if>
                    </xsl:for-each-group>
                </xsl:if>
            </div>
        </xsl:element>
    </xsl:template>
    <xsl:template name="xformElementUI">
        <xsl:param name="elementName"/>
        <xsl:param name="path"/>
        <xsl:param name="min"/>
        <xsl:param name="max"/>   
        <xsl:param name="level"/>   
        
        <xsl:variable name="elementRules" select="local:elementRules($elementName)"/>
        <xsl:variable name="referencedAttributeGroups" select="local:referencedAttributeGroups($elementName)"/>
        <xsl:variable name="childAttributes" select="local:childAttributes($elementName)"/>
        <xsl:variable name="allAttributes" select="local:allAttributes($elementName)"/>
        <xsl:variable name="childElements" select="local:elementRefs($elementName)"/>
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
        <xsl:element name="{$xformsElement}" namespace="http://www.w3.org/2002/xforms">
            <xsl:variable name="elementRef">
                <xsl:choose>
                    <xsl:when test="$level = 'root'">instance('i-rec')/<xsl:value-of select="$path"/></xsl:when>
                    <xsl:otherwise><xsl:value-of select="concat('tei:',$elementName)"/></xsl:otherwise>
                </xsl:choose>
            </xsl:variable>
            <xsl:attribute name="ref" select="$elementRef"/>
            <xsl:attribute name="id" select="generate-id(.)"/>
            <xsl:attribute name="class">xformsGroup</xsl:attribute>
            <div style="border:1px solid grey; padding:1em; margin:1em;">
                <div class="inlineBlock">
                    <xsl:choose>
                        <xsl:when test="$minOccur">
                            <xsl:choose>
                                <xsl:when test="$minOccur castable as xs:integer">
                                    <xsl:choose>
                                        <xsl:when test="xs:integer($minOccur) lt 1">
                                            <xf:trigger appearance="minimal" class="btn remove inline" xmlns="http://www.w3.org/2002/xforms">
                                                <xf:label/>
                                                <xf:delete ev:event="DOMActivate" ref="."/>
                                            </xf:trigger>
                                        </xsl:when>
                                        <xsl:when test="xs:integer($minOccur) = 1">
                                            <xf:trigger appearance="minimal" class="btn remove inline" ref=".[following-sibling::tei:{$elementName}]" xmlns="http://www.w3.org/2002/xforms">
                                                <xf:label/>
                                                <xf:delete ev:event="DOMActivate" ref="."/>
                                            </xf:trigger>
                                        </xsl:when>
                                        <xsl:when test="xs:integer($minOccur) gt 1">
                                            <xf:trigger appearance="minimal" class="btn remove inline" ref=".[following-sibling::tei:{$elementName}]" xmlns="http://www.w3.org/2002/xforms">
                                                <xf:label/>
                                                <xf:delete ev:event="DOMActivate" ref="."/>
                                            </xf:trigger>
                                        </xsl:when>
                                    </xsl:choose>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xf:trigger appearance="minimal" class="btn remove inline" xmlns="http://www.w3.org/2002/xforms">
                                        <xf:label/>
                                        <xf:delete ev:event="DOMActivate" ref="."/>
                                    </xf:trigger>
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:when>
                        <xsl:otherwise>
                            <xf:trigger appearance="minimal" class="btn remove inline" xmlns="http://www.w3.org/2002/xforms">
                                <xf:label/>
                                <xf:delete ev:event="DOMActivate" ref="."/>
                            </xf:trigger>
                        </xsl:otherwise>
                    </xsl:choose>
                    <span class="elementLable {$xformsElement}"><xsl:value-of select="$elementName"/> | </span>
                    <xsl:if test="$allAttributes/descendant-or-self::tei:attDef">
                        <!-- maybe put rules for additional attr./elements here, not an add button?  -->
                        <xf:select1 ref="instance('i-insert-attributes')//tei:attribute">
                            <xf:label>Available Attributes</xf:label>
                            <xf:item>
                                <xf:label>--- Select ---</xf:label>
                                <xf:value/>
                            </xf:item>
                            <xsl:for-each-group select="$allAttributes/descendant-or-self::tei:attDef" group-by="@ident">
                                <xsl:sort select="current-grouping-key()"/>
                                <xf:item>
                                    <xf:label><xsl:value-of select="current-grouping-key()"/></xf:label>
                                    <xf:value><xsl:value-of select="current-grouping-key()"/></xf:value>
                                </xf:item>
                            </xsl:for-each-group>
                            <!--
                                <xf:action ev:event="xforms-value-changed">
                                    <xf:insert
                                        context="{$path}"
                                        origin="instance('i-attributeTemplate')//@*[local-name(.) = instance('i-insert-attributes')//tei:attribute]"/>
                                    <xf:setvalue ref="instance('i-insert-attributes')//tei:attribute" value="''"/>
                                </xf:action>
                                -->
                        </xf:select1>
                        <xf:trigger class="btn add" appearance="minimal" ref=".">
                            <xf:label>add attribute</xf:label>
                            <xf:insert ev:event="DOMActivate" context="." at="." origin="instance('i-attributeTemplate')//@*[name(.) = instance('i-insert-attributes')//tei:attribute]"/>
                            <xf:setvalue ref="instance('i-insert-attributes')//tei:attribute" value="''"/>
                        </xf:trigger>
                    </xsl:if>
                    <xsl:if test="$elementRules/descendant::tei:content/descendant-or-self::tei:elementRef or $elementRules/descendant::tei:content/descendant-or-self::tei:classRef">
                        <xf:select1 ref="instance('i-insert-elements')//tei:element">
                            <xf:label>Available Elements</xf:label>
                            <xf:item>
                                <xf:label> Select </xf:label>
                                <xf:value/>
                            </xf:item>
                            <xsl:for-each-group select="$childElements/descendant-or-self::*:element[not(@classRef='true')]" group-by="@ident">
                                <xsl:sort select="current-grouping-key()"/>
                                <xf:item>
                                    <xf:label><xsl:value-of select="current-grouping-key()"/></xf:label>
                                    <xf:value><xsl:value-of select="current-grouping-key()"/></xf:value>
                                </xf:item>
                            </xsl:for-each-group>
                        </xf:select1>
                        <xf:trigger class="btn add" appearance="minimal" ref=".">
                            <xf:label>add element</xf:label>
                            <xf:insert ev:event="DOMActivate" context="." at="." origin="instance('i-elementTemplate')//*[local-name(.) = instance('i-insert-elements')//tei:element]"/>
                            <xf:setvalue ref="instance('i-insert-elements')//tei:element" value="''"/>
                        </xf:trigger>
                    </xsl:if>
                </div>
                <xsl:if test="$allAttributes/descendant-or-self::tei:attDef">
                    <xsl:for-each-group select="$childAttributes/descendant-or-self::tei:attDef" group-by="@ident">
                        <xsl:variable name="attRef" select="concat('@',current-grouping-key())"/>
                        <xsl:choose>
                            <xsl:when test="descendant-or-self::tei:valItem">
                                <!-- Controlled list - make sure controlled list matches the correct parent/parents-->
                                <span class="attribute-group">
                                    <xf:select1 ref="{$attRef}" xmlns="http://www.w3.org/2002/xforms">
                                        <xf:label><xsl:value-of select="current-grouping-key()"/></xf:label>
                                        <xf:item>
                                            <xf:label>--- Select ---</xf:label>
                                            <xf:value/>
                                        </xf:item>
                                        <xsl:for-each select="descendant-or-self::tei:valItem">
                                            <xf:item>
                                                <xf:label><xsl:value-of select="@ident"/></xf:label>
                                                <xf:value><xsl:value-of select="@ident"/></xf:value>
                                            </xf:item>
                                        </xsl:for-each>
                                    </xf:select1>
                                    <xf:trigger appearance="minimal" class="btn remove" ref="{$attRef}">
                                        <xf:label/>
                                        <xf:delete ev:event="DOMActivate" ref="."/>
                                    </xf:trigger>
                                </span>
                            </xsl:when>
                            <xsl:otherwise>
                                <span class="attribute-group"> 
                                    <xf:input ref="{$attRef}">
                                        <xf:label><xsl:value-of select="current-grouping-key()"/></xf:label>    
                                    </xf:input>
                                    <xf:trigger appearance="minimal" class="btn remove" ref="{$attRef}">
                                        <xf:label/>
                                        <xf:delete ev:event="DOMActivate" ref="."/>
                                    </xf:trigger>
                                </span>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:for-each-group>
                </xsl:if>
                <!-- 
                <xsl:for-each-group select="$elementRules/descendant-or-self::tei:classes/tei:memberOf[starts-with(@key,'att.')] | $elementRules/descendant-or-self::tei:classRef[starts-with(@key,'att.')]" group-by="@key">
                   <xsl:variable name="attrSubformRef" select="concat($app-root,'/subforms/attributes/',current-grouping-key(),'UI.xhtml')"></xsl:variable>
                    <xi:include href="{$attrSubformRef}"></xi:include>
                </xsl:for-each-group>
                -->
                <xsl:if test="$elementRules/descendant::tei:content/descendant::tei:textNode or (not($elementRules//tei:elementSpec/tei:content/descendant-or-self::tei:elementRef) or not($elementRules//tei:elementSpec/tei:content/descendant-or-self::tei:classRef))">
                    <!-- Text area --> 
                    <xsl:choose>
                        <xsl:when test="$elementName = 'p' or $elementName = 'desc'">
                            <xf:textarea ref="." xmlns="http://www.w3.org/2002/xforms">
                                <xf:label><xsl:value-of select="$elementName"/></xf:label>
                            </xf:textarea>
                        </xsl:when>
                        <xsl:otherwise>
                            <xf:input ref="." xmlns="http://www.w3.org/2002/xforms">
                                <xf:label><xsl:value-of select="$elementName"/></xf:label>
                            </xf:input>
                        </xsl:otherwise>
                    </xsl:choose>    
                </xsl:if> 
                <xsl:if test="$elementRules/descendant::tei:content/descendant-or-self::tei:elementRef or $elementRules/descendant::tei:content/descendant-or-self::tei:classRef">
                    <xsl:for-each-group select="$childElements/descendant-or-self::*:element[not(@classRef='true')]" group-by="@ident">
                        <xsl:if test="$elementName != current-grouping-key()">
                            <!--
                            <<xsl:variable name="subformRef" select="concat($app-root,'/subforms/elements/',current-grouping-key(),'UI.xhtml')"></xsl:variable>
                            <xi:include href="{$subformRef}"></xi:include>
                            -->
                            <xsl:call-template name="xformElementUI">
                                <xsl:with-param name="elementName" select="current-grouping-key()"/>
                                <xsl:with-param name="path" select="$path"/>
                                <xsl:with-param name="min" select="@minOccurs"/>
                                <xsl:with-param name="max" select="@maxOccurs"/>
                                <xsl:with-param name="level"/>
                            </xsl:call-template>
                        </xsl:if>
                    </xsl:for-each-group>
                </xsl:if>
            </div>
        </xsl:element>
    </xsl:template>
    
</xsl:stylesheet>