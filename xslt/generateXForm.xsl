<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet 
    xmlns="http://www.w3.org/1999/xhtml" 
    xmlns:tei="http://www.tei-c.org/ns/1.0" 
    xmlns:sc="http://www.ascc.net/xml/schematron" 
    xmlns:xf="http://www.w3.org/2002/xforms"
    xmlns:ev="http://www.w3.org/2001/xml-events"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="3.0">
    <!-- 
        MSS XForms
        NOTES: 
            use blank template to build form, each element in template against the schema?
            
            Steps
            Create model
            Create templates - maybe the same as create model
            Create view
            
            
    -->
    <xsl:param name="config" select="'config.xml'"/>
    <xsl:variable name="configDoc" select="document($config)"/>
    <xsl:variable name="localSchemaDoc" select="document($configDoc//schema/@src)"/>
    <xsl:variable name="mainSchemaDoc" select="document($configDoc//mainSchema/@src)"/>
    <!-- Find main tei schema -->
<!--    <xsl:variable name="TEISchemaDoc" select="doc($configDoc//schema/@src)"/>-->
    <xsl:variable name="template" select="document($configDoc//xmlTemplate/@src)"/>
    
    <xsl:output name="xform" encoding="UTF-8" method="xhtml" indent="yes" omit-xml-declaration="yes" xml:space="preserve" xpath-default-namespace="http://www.w3.org/1999/xhtml"/>
    <xsl:output name="tei" encoding="UTF-8" method="xml" indent="yes" xpath-default-namespace="http://www.tei-c.org/ns/1.0"/>
    
    <xsl:template match="/">
        <!-- Output JSON document -->
        <xsl:result-document href="xform.xhtml" format="xform">
            <xsl:call-template name="xform"/>
        </xsl:result-document>
        <!-- Output controlledValues template file -->
        <xsl:result-document href="controlledValues.xml" format="tei">
           <xsl:call-template name="controlledValues"/>
        </xsl:result-document>
        <xsl:result-document href="template.xml" format="tei">
            <xsl:call-template name="template"/>
        </xsl:result-document>
    </xsl:template>
    <xsl:template name="xform">
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
                    <!-- Build contstraints 
                    <xsl:for-each select="$template/child::*">
                        <xsl:apply-templates mode="formRules"/>
                    </xsl:for-each>
                    -->
                    <!-- Create optional lookups -->
                    <!-- Create submit -->
                </xf:model>
            </head>
            <body>       
                <div class="section xforms">
                    <!-- Create view (inputs) -->
                    <!-- 
                        1. Check template for element
                        2. Check template and/or schema for optional attributes and child elements
                        3. If attributes, create inputs and dropdowns, with controlled values if specified in schema
                        3. If terminal element, build input options.
                    -->
                    <xsl:for-each select="$template/child::*">
                        <!-- <xsl:call-template name="buildXFormsElement"/> -->
                        <xsl:apply-templates mode="formElement"/>
                    </xsl:for-each>
                </div>
            </body>
        </html>
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
    <!--
    <xsl:template match="*:define" mode="controlledValues">
        
    </xsl:template>
    -->
    <xsl:template match="text()" mode="controlledValues"/>
    <xsl:template match="*" mode="formElement">
        <xsl:variable name="elementName" select="local-name(.)"/>
        <xsl:variable name="elementRules">
            <xsl:for-each select="$localSchemaDoc//descendant-or-self::tei:elementSpec[@ident=$elementName]">
                <xsl:copy-of select="."/>
            </xsl:for-each>
        </xsl:variable>
        <div style="border:1px solid grey; padding:2px;">
            <xsl:variable name="path" select="replace(replace(path(.),'Q\{http://www.tei-c.org/ns/1.0\}','tei:'),'tei:TEI','/')"/>
            <xf:group ref="instance('i-rec'){$path}" id="{generate-id(.)}" class="xformsGroup">
                <div class="inlineBlock">
                        <xf:trigger appearance="minimal" class="btn remove inline">
                            <xf:label/>
                            <xf:delete ev:event="DOMActivate" ref="."/>
                        </xf:trigger>
                        <h4 class="inline">
                            <xsl:value-of select="$elementName"/>
                        </h4>
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
                            <xsl:when test="$elementRules/descendant::tei:attDef[@ident=local-name(.)]/tei:valList">
                                <xf:select1 ref="{concat('@',name(.))}">
                                    <xf:label><xsl:value-of select="name(.)"/></xf:label>
                                    <xf:item>
                                        <xf:label>--- Select ---</xf:label>
                                        <xf:value/>
                                    </xf:item>
                                    <!--
                                    <xsl:for-each select="$elementRules/descendant::tei:attDef[@ident=local-name(.)]/tei:valList/tei:valItem">
                                        <xf:item>
                                            <xf:label ref="@ident"/>
                                            <xf:value ref="@ident"/>
                                        </xf:item> 
                                    </xsl:for-each>
                                    -->
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
                <xsl:for-each select="$elementRules/descendant::tei:attDef">
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
                <xsl:apply-templates mode="formElement"/> 
            </xf:group>
        </div>
    </xsl:template>
    <xsl:template match="*" mode="formRules">
        <!-- Place Holder -->
    </xsl:template>
    <!-- named templates used to build a full example template to pull optional attributes and elements from. Based on Local Schema first, then main schema -->
    <xsl:template match="*" mode="template">
        <xsl:variable name="elementName" select="local-name(.)"/>
        <!-- Check schema for rules -->
        <xsl:variable name="elementRules">
            <xsl:choose>
                <xsl:when test="$localSchemaDoc//descendant-or-self::tei:elementSpec[@ident=$elementName]">
                    <!-- Local schema (xml) -->
                    <xsl:for-each select="$localSchemaDoc//descendant-or-self::tei:elementSpec[@ident=$elementName]">
                        <xsl:copy-of select="."/>
                    </xsl:for-each>
                </xsl:when>
                <xsl:when test="$localSchemaDoc//descendant-or-self::*:define[@name=$elementName]">
                    <!-- Local schema (rng) -->
                    <xsl:for-each select="$localSchemaDoc//descendant-or-self::*:define[@name=$elementName]">
                        <xsl:copy-of select="."/>
                    </xsl:for-each>
                </xsl:when>
                <xsl:when test="$mainSchemaDoc//descendant-or-self::*:define[@name=$elementName]">
                    <!-- Look in main rng file.  -->
                    <xsl:for-each select="$mainSchemaDoc//descendant-or-self::*:define[@name=$elementName]">
                        <xsl:copy-of select="."/>
                    </xsl:for-each>
                </xsl:when>
            </xsl:choose>
        </xsl:variable>
        <xsl:element name="{$elementName}" namespace="http://www.tei-c.org/ns/1.0">
            <!-- Add attributes -->
            <xsl:for-each select="$elementRules/descendant::tei:attDef">
                <!--WS:Note,  Can add optional or required?  ex: <attDef ident="evidence" mode="add" usage="opt"> -->
                <xsl:attribute name="{string(@ident)}"></xsl:attribute>
            </xsl:for-each>
            <xsl:for-each select="$elementRules/descendant::*:attribute">
                <xsl:attribute name="{string(@name)}"></xsl:attribute>
            </xsl:for-each>
            <xsl:copy-of select="@*"/>
            <xsl:copy-of select="$elementRules/descendant::tei:content/child::*[@maxOccurs][1]/@maxOccurs"/>
            <!-- WS:note work in progress
                <xsl:if test="$elementRules/descendant::content">
                    <xsl:for-each select="$elementRules/descendant::content"></xsl:for-each>
                </xsl:if>
                -->
            <xsl:apply-templates mode="template"/>
        </xsl:element> 
    </xsl:template>
   
</xsl:stylesheet>