<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns="http://www.w3.org/1999/xhtml" xmlns:tei="http://www.tei-c.org/ns/1.0"
    xmlns:sc="http://www.ascc.net/xml/schematron" xmlns:xf="http://www.w3.org/2002/xforms"
    xmlns:ev="http://www.w3.org/2001/xml-events" xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:xi="http://www.w3.org/2001/XInclude" xmlns:local="http://syriaca.org/ns"
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
    <!-- 
        WS:Note 
        TEI macrRefs tend to lead to endless looping, especially plike and macro.phraseSeq
        May need to ignore or turn into p elements for my own sanity
    -->
    <xsl:param name="config" select="'config.xml'"/>
    <xsl:variable name="configDoc" select="document($config)"/>
    <!-- Form languge -->
    <xsl:variable name="formLang">
        <xsl:choose>
            <xsl:when test="$configDoc//formLang[. != '']">
                <xsl:value-of select="$configDoc//formLang"/>
            </xsl:when>
            <xsl:otherwise>en</xsl:otherwise>
        </xsl:choose>
    </xsl:variable>
    <!-- Local schema customizations -->
    <xsl:variable name="localSchemaDoc" select="document($configDoc//localSchema/@src)"/>
    <!-- Global schema -->
    <xsl:variable name="globalSchemaDoc" select="document($configDoc//globalSchema/@src)"/>
    <!-- Template for building form -->
    <xsl:variable name="template" select="document($configDoc//xmlTemplate/@src)"/>
    <!-- app root -->
    <xsl:variable name="app-root" select="'http://localhost:8080/exist/apps/mssXForms/forms'"/>
    <xsl:output name="xform" encoding="UTF-8" method="xhtml" indent="yes" omit-xml-declaration="yes" xml:space="preserve" xpath-default-namespace="http://www.w3.org/1999/xhtml"/>
    <xsl:output name="tei" encoding="UTF-8" method="xml" indent="yes"
        xpath-default-namespace="http://www.tei-c.org/ns/1.0"/>

    <!-- Check schema for element rules
        WS:Note will need to refine so we get local/global and then check against each other for final set of rules. 
    -->
    <!-- Helper functions -->
    <xsl:function name="local:localElementRules">
        <xsl:param name="elementName"/>
        <xsl:for-each select="$localSchemaDoc//descendant-or-self::*:elementSpec[@ident = $elementName]">
            <xsl:copy-of select="."/>
        </xsl:for-each>
    </xsl:function>
    <xsl:function name="local:globalElementRules">
        <xsl:param name="elementName"/>
        <xsl:for-each
            select="$globalSchemaDoc//descendant-or-self::*:elementSpec[@ident = $elementName]">
            <xsl:copy-of select="."/>
        </xsl:for-each>
    </xsl:function>
    <xsl:function name="local:parentElementRules">
        <xsl:param name="parentElementName"/>
        <xsl:for-each
            select="$localSchemaDoc//descendant-or-self::tei:elementSpec[@ident = $parentElementName]">
            <xsl:copy-of select="."/>
        </xsl:for-each>
    </xsl:function>
    <xsl:function name="local:elementRules">
        <xsl:param name="elementName"/>
        <rules xmlns="http://www.tei-c.org/ns/1.0">
            <local>
                <xsl:for-each select="$localSchemaDoc//descendant-or-self::tei:elementSpec[@ident = $elementName]">
                    <xsl:copy-of select="."/>
                </xsl:for-each>
            </local>
            <global>
                <xsl:for-each select="$globalSchemaDoc//descendant-or-self::tei:elementSpec[@ident = $elementName]">
                    <xsl:copy-of select="."/>
                </xsl:for-each>
            </global>
        </rules>
    </xsl:function>
    <xsl:function name="local:childElements">
        <xsl:param name="elementName"/>
        <xsl:variable name="elementRules" select="local:elementRules($elementName)"/>
        <xsl:variable name="elementRefs">
            <xsl:variable name="rules">
                <xsl:choose>
                    <xsl:when test="$elementRules/tei:local/descendant-or-self::tei:content">
                        <xsl:copy-of select="$elementRules/tei:local"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:copy-of select="$elementRules/tei:global"/>
                    </xsl:otherwise>
                </xsl:choose> 
            </xsl:variable>
            <xsl:for-each-group select="$rules/descendant-or-self::tei:content/descendant-or-self::*[@key]" group-by="@key">
                    <xsl:choose>
                        <xsl:when test="current-grouping-key() = ('model.gLike','macro.xtext','macro.phraseSeq','macro.specialPara')">
                            <element xmlns="http://www.tei-c.org/ns/1.0" ident="p"/>
                        </xsl:when>
                        <xsl:when test="contains(current-grouping-key(),'.')">
                            <xsl:choose>
                                <xsl:when test="contains(current-grouping-key(),'macro.')">
                                    <xsl:copy-of select="local:resolveMacroSpec(current-grouping-key())"></xsl:copy-of> 
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:copy-of select="local:resolveClassRef(current-grouping-key())"></xsl:copy-of>
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:when>
                        <xsl:otherwise>
                            <element xmlns="http://www.tei-c.org/ns/1.0" ident="{current-grouping-key()}"/>
                        </xsl:otherwise>
                    </xsl:choose>
            </xsl:for-each-group>            
        </xsl:variable>
        <child>
            <xsl:copy-of select="$elementRefs"/>
        </child>
    </xsl:function>
    <!-- resolve class refs -->
    <xsl:function name="local:resolveClassRef">
        <xsl:param name="className"/>
        <xsl:variable name="localRules">
            <xsl:for-each select="$localSchemaDoc//descendant-or-self::*[tei:classes/tei:memberOf[@key = $className]]">
                <xsl:choose>
                    <xsl:when test=".[@mode = 'delete']">
                        <element xmlns="http://www.tei-c.org/ns/1.0" class="deleted local"/>
                    </xsl:when>
                    <xsl:when test=".[@mode = 'change' or @mode = 'replace']">
                        <xsl:choose>
                            <xsl:when test="self::tei:elementSpec">
                                <element xmlns="http://www.tei-c.org/ns/1.0" ident="{string(@ident)}" class="local"/>
                            </xsl:when>
                            <xsl:when test="self::tei:classSpec">
                                <xsl:variable name="subClassName" select="@ident"/>
                                <xsl:copy-of select="local:resolveClassRef($subClassName)"/>
                            </xsl:when>
                            <xsl:otherwise><xsl:value-of select="name(.)"/></xsl:otherwise>
                        </xsl:choose>
                    </xsl:when>
                </xsl:choose>     
            </xsl:for-each>
        </xsl:variable>
        <xsl:choose>
            <xsl:when test="$localRules/descendant-or-self::tei:element">
                <xsl:copy-of select="$localRules"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:for-each select="$globalSchemaDoc//descendant-or-self::*[tei:classes/tei:memberOf[@key = $className]]">
                    <xsl:choose>
                        <xsl:when test="self::tei:elementSpec">
                            <element xmlns="http://www.tei-c.org/ns/1.0" ident="{string(@ident)}" class="global"/>
                        </xsl:when>
                        <xsl:when test="self::tei:classSpec">
                            <xsl:variable name="subClassName" select="@ident"/>
                            <xsl:copy-of select="local:resolveClassRef($subClassName)"/>
                        </xsl:when>
                        <xsl:otherwise><xsl:value-of select="name(.)"/></xsl:otherwise>
                    </xsl:choose>
                </xsl:for-each>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>
    <xsl:function name="local:resolveMacroSpec">
        <xsl:param name="macroSpec"/>
        <xsl:variable name="localRules">
            <xsl:for-each select="$globalSchemaDoc/descendant-or-self::tei:macroSpec[@ident = $macroSpec]/descendant-or-self::tei:content/descendant-or-self::*[@key]">
                <xsl:choose>
                    <xsl:when test=".[@mode = 'delete']">
                        <element xmlns="http://www.tei-c.org/ns/1.0" class="local deleted"/>
                    </xsl:when>
                    <xsl:when test=".[@mode = 'change' or @mode = 'replace']">
                        <xsl:choose>
                            <xsl:when test="self::tei:elementSpec">
                                <element xmlns="http://www.tei-c.org/ns/1.0" ident="{string(@ident)}" class="local"/>
                            </xsl:when>
                            <xsl:when test="self::tei:classSpec">
                                <xsl:variable name="subClassName" select="@ident"/>
                                <xsl:copy-of select="local:resolveClassRef($subClassName)"/>
                            </xsl:when>
                            <xsl:when test="self::tei:classRef">
                                <xsl:variable name="subClassName" select="@key"/>
                                <xsl:copy-of select="local:resolveClassRef($subClassName)"/>
                            </xsl:when>
                            <xsl:when test="self::tei:elementRef">
                                <element xmlns="http://www.tei-c.org/ns/1.0" ident="{string(@key)}" class="local">
                                    <xsl:copy-of select="."/>
                                </element>
                            </xsl:when>
                        </xsl:choose>
                    </xsl:when>
                </xsl:choose>  
            </xsl:for-each>
        </xsl:variable>
        <xsl:choose>
            <xsl:when test="$localRules/descendant-or-self::tei:element">
                <xsl:copy-of select="$localRules"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:for-each select="$globalSchemaDoc/descendant-or-self::tei:macroSpec[@ident = $macroSpec]/descendant-or-self::tei:content/descendant-or-self::*[@key]">
                    <xsl:choose>
                        <xsl:when test="self::tei:elementSpec">
                            <element xmlns="http://www.tei-c.org/ns/1.0" ident="{string(@ident)}" class="global"/>
                        </xsl:when>
                        <xsl:when test="self::tei:classSpec">
                            <xsl:variable name="subClassName" select="@ident"/>
                            <xsl:copy-of select="local:resolveClassRef($subClassName)"/>
                        </xsl:when>
                        <xsl:when test="self::tei:classRef">
                            <xsl:variable name="subClassName" select="@key"/>
                            <xsl:copy-of select="local:resolveClassRef($subClassName)"/>
                        </xsl:when>
                        <xsl:when test="self::tei:elementRef">
                            <element xmlns="http://www.tei-c.org/ns/1.0" ident="{string(@key)}" class="global">
                                <xsl:copy-of select="."/>
                            </element>
                        </xsl:when>
                        <xsl:otherwise><xsl:value-of select="name(.)"/></xsl:otherwise>
                    </xsl:choose>
                </xsl:for-each>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>
    
    <xsl:function name="local:resolveElementClassRef">
        <xsl:param name="className"/>
        <xsl:variable name="localClass">
            <xsl:for-each select="$localSchemaDoc//descendant-or-self::*[tei:classes/tei:memberOf[@key = $className]]">
                <xsl:choose>
                    <xsl:when test="self::tei:elementSpec">
                        <element xmlns="http://www.tei-c.org/ns/1.0" ident="{string(@ident)}" className="{$className}">
                            <xsl:value-of select="string(@ident)"/>
                        </element>
                    </xsl:when>
                    <xsl:when test="self::tei:classSpec">
                        <xsl:variable name="subClassName" select="@ident"/>
                        <xsl:copy-of select="local:resolveElementClassRef($subClassName)"/>
                    </xsl:when>
                </xsl:choose>
            </xsl:for-each>
        </xsl:variable>
        <xsl:choose>
            <xsl:when test="$localClass//*:element">
                <xsl:copy-of select="$localClass"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:for-each select="$globalSchemaDoc//descendant-or-self::*[tei:classes/tei:memberOf[@key = $className]]">
                    <xsl:choose>
                        <xsl:when test="self::tei:elementSpec">
                            <element xmlns="http://www.tei-c.org/ns/1.0" ident="{string(@ident)}" className="{$className}">
                                <xsl:value-of select="string(@ident)"/>
                            </element>
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
    <!-- Older function, moving away from this -->
    <xsl:function name="local:elementRefs">
        <xsl:param name="elementName"/>
        <xsl:variable name="elementRules" select="local:elementRules($elementName)"/>
        <xsl:variable name="childElement" select="$elementRules/descendant-or-self::tei:elementRef | $elementRules/descendant-or-self::tei:classRef | $elementRules/descendant-or-self::tei:macroRef"/>
        <xsl:variable name="keys" select="distinct-values($elementRules/descendant-or-self::tei:elementRef/@key | $elementRules/descendant-or-self::tei:classRef/@key | $elementRules/descendant-or-self::tei:macroRef/@key)"/>
        <xsl:for-each-group select="$childElement" group-by="@key">
            <element xmlns="http://www.tei-c.org/ns/1.0" ident="{string(current-grouping-key())}">
                <xsl:copy-of select="@*"/>
                <xsl:choose>
                    <xsl:when test="self::tei:classRef">
                        <xsl:attribute name="classRef" select="'true'"/>
                        <xsl:copy-of select="local:resolveElementClassRef(current-grouping-key())"/>
                    </xsl:when>
                    <xsl:when test="self::tei:macroRef">
                    <!-- placeholder  -->
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:value-of select="current-grouping-key()"/>
                    </xsl:otherwise>
                </xsl:choose>
            </element>
        </xsl:for-each-group>
    </xsl:function>
    <xsl:function name="local:classSpecAtt">
        <xsl:param name="className"/>
        <xsl:variable name="localClasses" select="$localSchemaDoc//descendant-or-self::tei:classSpec[@ident = $className]"/>
        <xsl:variable name="globalClasses" select="$globalSchemaDoc//descendant-or-self::tei:classSpec[@ident = $className]"/>
        <rules xmlns="http://www.tei-c.org/ns/1.0">
            <local>
                <xsl:for-each select="$localClasses/descendant-or-self::tei:attList/descendant-or-self::tei:attDef">
                    <xsl:copy-of select="."/>
                </xsl:for-each>
                <xsl:variable name="memberOf" select="$localClasses/descendant-or-self::tei:classes/tei:memberOf[starts-with(@key, 'att.')]/@key"/>
                <xsl:for-each select="$memberOf">
                    <xsl:copy-of select="local:classSpecAtt($memberOf)"/>
                </xsl:for-each>
            </local>
            <global>
                <xsl:for-each select="$globalClasses/descendant-or-self::tei:attList/descendant-or-self::tei:attDef">
                    <xsl:copy-of select="."/>
                </xsl:for-each>
                <xsl:variable name="memberOf" select="$globalClasses/descendant-or-self::tei:classes/tei:memberOf[starts-with(@key, 'att.')]/@key"/>
                <xsl:for-each select="$memberOf">
                    <xsl:copy-of select="local:classSpecAtt($memberOf)"/>
                </xsl:for-each>
            </global>
        </rules>
    </xsl:function>
    <xsl:function name="local:allAttributes">
        <xsl:param name="elementName"/>
        <xsl:variable name="elementRules" select="local:elementRules($elementName)"/>
        <xsl:variable name="childAtt" select="$elementRules/descendant-or-self::tei:attList/descendant-or-self::tei:attDef"/>
<!--        <xsl:variable name="memberOf" select="$elementRules/descendant-or-self::tei:classes/tei:memberOf[starts-with(@key, 'att.')]/@key"/>-->
        <xsl:variable name="memberOfAtt">
            <xsl:for-each select="$elementRules/descendant-or-self::tei:classes/tei:memberOf[starts-with(@key, 'att.')]">
                <xsl:choose>
                    <xsl:when test=".[@mode='delete'][ancestor-or-self::tei:local]"></xsl:when>
                    <xsl:when test=".[@mode='change'][ancestor-or-self::tei:local]"><xsl:copy-of select="local:classSpecAtt(.[@mode='change'][ancestor-or-self::tei:local][1]/@key)"/></xsl:when>
                    <xsl:when test=".[@mode='opt'][ancestor-or-self::tei:local]"><xsl:copy-of select="local:classSpecAtt(.[@mode='opt'][ancestor-or-self::tei:local][1]/@key)"/></xsl:when>
                    <xsl:when test=".[@mode='add'][ancestor-or-self::tei:local]"><xsl:copy-of select="local:classSpecAtt(.[@mode='add'][ancestor-or-self::tei:local][1]/@key)"/></xsl:when>
                    <xsl:when test=".[@mode='replace'][ancestor-or-self::tei:local]"><xsl:copy-of select="local:classSpecAtt(.[@mode='replace'][ancestor-or-self::tei:local][1]/@key)"/></xsl:when>
                    <xsl:otherwise><xsl:copy-of select=".[1]"/></xsl:otherwise>
                </xsl:choose>
<!--                <xsl:copy-of select="local:classSpecAtt($memberOf)"/>-->
            </xsl:for-each>
        </xsl:variable>
        <availableAtts xmlns="http://www.tei-c.org/ns/1.0" elementName="{$elementName}">
            <xsl:for-each-group select="$childAtt/descendant-or-self::tei:attDef | $memberOfAtt/descendant-or-self::tei:attDef" group-by="@ident">
                <xsl:sort select="current-grouping-key()"/>
                    <xsl:choose>
                        <xsl:when test=".[@mode='delete'][ancestor-or-self::tei:local]"></xsl:when>
                        <xsl:when test=".[@mode='change'][ancestor-or-self::tei:local]"><xsl:copy-of select=".[@mode='change'][ancestor-or-self::tei:local][1]"/></xsl:when>
                        <xsl:when test=".[@mode='opt'][ancestor-or-self::tei:local]"><xsl:copy-of select=".[@mode='opt'][ancestor-or-self::tei:local][1]"/></xsl:when>
                        <xsl:when test=".[@mode='add'][ancestor-or-self::tei:local]"><xsl:copy-of select=".[@mode='add'][ancestor-or-self::tei:local][1]"/></xsl:when>
                        <xsl:when test=".[@mode='replace'][ancestor-or-self::tei:local]"><xsl:copy-of select=".[@mode='replace'][ancestor-or-self::tei:local][1]"/></xsl:when>
                        <xsl:otherwise><xsl:copy-of select="."/></xsl:otherwise>
                    </xsl:choose>
            </xsl:for-each-group>            
        </availableAtts>
    </xsl:function>

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
            <xsl:call-template name="elementTemplate"/>
        </xsl:result-document>
        <xsl:result-document href="attributesTemplate.xml" format="tei">
            <xsl:call-template name="attributesTemplate"/>
        </xsl:result-document>
    </xsl:template>
    
    <xsl:template name="xform">
        <xsl:param name="subform"/>
        <xsl:text disable-output-escaping="yes">&lt;!DOCTYPE html&gt;</xsl:text>
        <html xmlns="http://www.w3.org/1999/xhtml" xmlns:xi="http://www.w3.org/2001/XInclude"
            xmlns:ev="http://www.w3.org/2001/xml-events" xmlns:tei="http://www.tei-c.org/ns/1.0"
            xmlns:xf="http://www.w3.org/2002/xforms">
            <head>
                <title>
                    <xsl:value-of select="$configDoc//formTitle"/>
                </title>
                <meta name="author" content="{$configDoc//formAuthor}"/>
                <meta name="description" content="{$configDoc//formDesc}"/>
                <link rel="stylesheet" type="text/css"
                    href="resources/bootstrap/css/bootstrap.min.css"/>
                <link rel="stylesheet" type="text/css" href="resources/css/xforms.css"/>
                <link href="resources/jquery-ui/jquery-ui.min.css" rel="stylesheet"/>
                <script type="text/javascript" src="resources/js/jquery.min.js"/>
                <script type="text/javascript" src="resources/bootstrap/js/bootstrap.min.js"/>
                <xf:model id="m-mss">
                    <!-- Create instances -->
                    <xf:instance id="i-rec" src="forms/templates/{$configDoc//xmlTemplate/@src}"/>
                    <xf:instance id="i-template" src="forms/templates/template.xml"/>
                    <xf:instance id="i-ctr-vals" src="forms/templates/controlledValues.xml"/>
                    <xf:instance id="i-elementTemplate" src="forms/templates/elementTemplate.xml"/>
                    <xf:instance id="i-attributeTemplate" src="forms/templates/attributesTemplate.xml"/>
                    <!-- i-insert-elements -->
                    <xf:instance id="i-insert-elements">
                        <TEI xmlns="http://www.tei-c.org/ns/1.0">
                            <element/>
                        </TEI>
                    </xf:instance>
                    <xf:instance id="i-insert-attributes">
                        <TEI xmlns="http://www.tei-c.org/ns/1.0">
                            <attribute/>
                        </TEI>
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
                            <xf:message ev:event="xforms-submit-error" level="modal">Unable to
                                submit your additions at this time, you may download your changes
                                and email them to us.</xf:message>
                        </xf:action>
                    </xf:submission>
                </xf:model>
            </head>
            <body>
                <div class="section xforms">
                    <xsl:call-template name="submission"/>
                    <h1>
                        <xsl:value-of select="$subform/@formName"/>
                    </h1>
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
                        <xsl:variable name="elementPath" select="replace(replace(replace(replace(path(.), 'Q\{http://www.tei-c.org/ns/1.0\}', 'tei:'), 'tei:TEI', '/'), '\[[0-9]+\]', ''), '///', '//')"/>
                        <xsl:variable name="elementName" select="local-name(.)"/>
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
        <xsl:if test="tei:attList/tei:attDef[tei:valList[@type = 'closed']]">
            <xsl:element name="{string(@ident)}" namespace="http://www.tei-c.org/ns/1.0">
                <xsl:for-each select="tei:attList/tei:attDef[tei:valList[@type = 'closed']]">
                    <xsl:element name="{string(@ident)}" namespace="http://www.tei-c.org/ns/1.0">
                        <xsl:copy-of select="tei:valList[@type = 'closed']"/>
                    </xsl:element>
                </xsl:for-each>
            </xsl:element>
        </xsl:if>
    </xsl:template>
    <xsl:template match="text()" mode="controlledValues"/>  
    <!-- 
        This named templates is used to build a full example template to pull ALL elements from. 
        Adds all elements/attributes listed in global or local schemas
    -->
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

    <xsl:template name="attributesTemplate">
        <TEI xmlns="http://www.tei-c.org/ns/1.0">
            <element>
                <!-- Go through global and local schema, output one of every attribute -->
                <xsl:for-each-group
                    select="$globalSchemaDoc//tei:attDef | $localSchemaDoc//tei:attDef"
                    group-by="@ident">
                    <xsl:sort select="@ident" order="ascending"/>
                    <xsl:variable name="attName" select="@ident"/>
                    <xsl:attribute name="{$attName}"/>
                </xsl:for-each-group>
            </element>
        </TEI>
    </xsl:template>
   
    <xsl:template name="xformElementUITest">
        <xsl:param name="elementName"/>
        <xsl:param name="path"/>
        <xsl:param name="min"/>
        <xsl:param name="max"/>
        <xsl:param name="level"/>
        
        <xsl:variable name="elementRules" select="local:elementRules($elementName)"/>
        <xsl:variable name="allAttributes" select="local:allAttributes($elementName)"/>
        <xsl:variable name="childElements" select="local:childElements($elementName)"/>
        <xsl:variable name="path" select="concat($path, '/tei:', $elementName)"/>
        <xsl:variable name="id" select="replace(replace(concat(replace($path,'/',''),generate-id(.)),' ',''),'tei:','')"/>
        <xsl:variable name="elementLabel">
            <xsl:choose>
                <xsl:when test="$elementRules/descendant::tei:gloss[@xml:lang = $formLang]">
                    <xsl:value-of select="$elementRules/descendant::tei:gloss[@xml:lang = $formLang][1]"/>
                </xsl:when>
                <xsl:when test="$elementRules/descendant::tei:gloss[@xml:lang = 'en']">
                    <xsl:value-of select="$elementRules/descendant::tei:gloss[@xml:lang = 'en'][1]"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="$elementName"/>
                </xsl:otherwise>
            </xsl:choose> 
        </xsl:variable>
        <xsl:variable name="maxOccur">
            <xsl:choose>
                <xsl:when test="$max != ''">
                    <xsl:value-of select="$max"/>
                </xsl:when>
                <xsl:when test="$elementRules/tei:content/tei:sequence[@maxOccur]">
                    <xsl:value-of select="string($elementRules/tei:content/tei:sequence/@maxOccur)"/>
                </xsl:when>
                <xsl:otherwise/>
            </xsl:choose>
        </xsl:variable>
        <xsl:variable name="minOccur">
            <xsl:choose>
                <xsl:when test="$min != ''">
                    <xsl:value-of select="$min"/>
                </xsl:when>
                <xsl:when test="$elementRules/tei:content/tei:sequence[@minOccur]">
                    <xsl:value-of select="string($elementRules/tei:content/tei:sequence/@minOccur)"/>
                </xsl:when>
                <xsl:otherwise/>
            </xsl:choose>
        </xsl:variable>
        <xsl:variable name="xformsElement">
            <xsl:choose>
                <xsl:when test="$maxOccur = 'unbounded' or $maxOccur = ''">repeat</xsl:when>
                <xsl:otherwise>group</xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <!-- Build XForm element -->
        <div class="childElements">
            <xsl:copy-of select="local:childElements($elementName)"/>
        </div>
        <xsl:element name="{$xformsElement}" namespace="http://www.w3.org/2002/xforms">
            <xsl:variable name="elementRef">
                <xsl:choose>
                    <xsl:when test="$level = 'root'">instance('i-rec')/<xsl:value-of select="$path"/></xsl:when>
                    <xsl:otherwise>
                        <xsl:value-of select="concat('tei:', $elementName)"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:variable>
            <xsl:attribute name="ref" select="$elementRef"/>
            <xsl:attribute name="id" select="$id"/>
            <xsl:attribute name="class">xformsGroup</xsl:attribute>
            <div class="xformElement">
                <!-- Element controls and label -->
                <div class="inlineBlock">
                    <xsl:choose>
                        <xsl:when test="$minOccur">
                            <xsl:choose>
                                <xsl:when test="$minOccur castable as xs:integer">
                                    <xsl:choose>
                                        <xsl:when test="xs:integer($minOccur) &lt; 1">
                                            <xf:trigger appearance="minimal" class="btn remove inline" xmlns="http://www.w3.org/2002/xforms">
                                                <xf:label/>
                                                <xf:delete ev:event="DOMActivate" ref="."/>
                                            </xf:trigger>
                                        </xsl:when>
                                        <xsl:when test="xs:integer($minOccur) &gt; 0">
                                            <xf:trigger appearance="minimal" class="btn remove inline" ref=".[count(../tei:{$elementName}) &gt; {$minOccur}]" xmlns="http://www.w3.org/2002/xforms">
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
                    <span class="elementLable {$xformsElement}"><xsl:value-of select="$elementLabel"/></span>
                </div>
                <!--  Include child elements inline, runs into nesting errors when generating -->
                <xsl:if test="$childElements/descendant-or-self::*:element[not(@classRef = 'true')]">
                    <xsl:for-each-group select="$childElements/descendant-or-self::*:element[not(@classRef = 'true')]" group-by="@ident">
                        <div class="{current-grouping-key()}">
                            <xsl:copy-of select="local:childElements(current-grouping-key())"/>
                        </div>
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
        <xsl:variable name="allAttributes" select="local:allAttributes($elementName)"/>
        <xsl:variable name="childElements" select="local:childElements($elementName)"/>
        <xsl:variable name="path" select="concat($path, '/tei:', $elementName)"/>
        <xsl:variable name="id" select="replace(replace(concat(replace($path,'/',''),generate-id(.)),' ',''),'tei:','')"/>
        <xsl:variable name="elementLabel">
            <xsl:choose>
                <xsl:when test="$elementRules/descendant::tei:gloss[@xml:lang = $formLang]">
                    <xsl:value-of select="$elementRules/descendant::tei:gloss[@xml:lang = $formLang][1]"/>
                </xsl:when>
                <xsl:when test="$elementRules/descendant::tei:gloss[@xml:lang = 'en']">
                    <xsl:value-of select="$elementRules/descendant::tei:gloss[@xml:lang = 'en'][1]"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="$elementName"/>
                </xsl:otherwise>
            </xsl:choose> 
        </xsl:variable>
        <xsl:variable name="maxOccur">
            <xsl:choose>
                <xsl:when test="$max != ''">
                    <xsl:value-of select="$max"/>
                </xsl:when>
                <xsl:when test="$elementRules/tei:content/tei:sequence[@maxOccur]">
                    <xsl:value-of select="string($elementRules/tei:content/tei:sequence/@maxOccur)"/>
                </xsl:when>
                <xsl:otherwise/>
            </xsl:choose>
        </xsl:variable>
        <xsl:variable name="minOccur">
            <xsl:choose>
                <xsl:when test="$min != ''">
                    <xsl:value-of select="$min"/>
                </xsl:when>
                <xsl:when test="$elementRules/tei:content/tei:sequence[@minOccur]">
                    <xsl:value-of select="string($elementRules/tei:content/tei:sequence/@minOccur)"/>
                </xsl:when>
                <xsl:otherwise/>
            </xsl:choose>
        </xsl:variable>
        <xsl:variable name="xformsElement">
            <xsl:choose>
                <xsl:when test="$maxOccur = 'unbounded' or $maxOccur = ''">repeat</xsl:when>
                <xsl:otherwise>group</xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <!-- Build XForm element -->
        <xsl:element name="{$xformsElement}" namespace="http://www.w3.org/2002/xforms">
            <xsl:variable name="elementRef">
                <xsl:choose>
                    <xsl:when test="$level = 'root'">instance('i-rec')/<xsl:value-of select="$path"/></xsl:when>
                    <xsl:otherwise>
                        <xsl:value-of select="concat('tei:', $elementName)"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:variable>
            <xsl:attribute name="ref" select="$elementRef"/>
            <xsl:attribute name="id" select="$id"/>
            <xsl:attribute name="class">xformsGroup</xsl:attribute>
            <div class="xformElement">
                <!-- Element controls and label -->
                <div class="inlineBlock">
                    <xsl:choose>
                        <xsl:when test="$minOccur">
                            <xsl:choose>
                                <xsl:when test="$minOccur castable as xs:integer">
                                    <xsl:choose>
                                        <xsl:when test="xs:integer($minOccur) &lt; 1">
                                            <xf:trigger appearance="minimal" class="btn remove inline" xmlns="http://www.w3.org/2002/xforms">
                                                <xf:label/>
                                                <xf:delete ev:event="DOMActivate" ref="."/>
                                            </xf:trigger>
                                        </xsl:when>
                                        <xsl:when test="xs:integer($minOccur) &gt; 0">
                                            <xf:trigger appearance="minimal" class="btn remove inline" ref=".[count(../tei:{$elementName}) &gt; {$minOccur}]" xmlns="http://www.w3.org/2002/xforms">
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
                    <span class="elementLable {$xformsElement}"><xsl:value-of select="$elementLabel"/></span>
                    <xsl:if test="$allAttributes/descendant-or-self::tei:attDef"> | 
                        <div class="dropdown">
                            <button class="btn btn-default dropdown-toggle" type="button" id="{concat('availAttributes',$id)}" data-toggle="dropdown">
                                Available Attributes <span class="caret"></span>
                            </button>
                            <ul class="dropdown-menu" role="menu" aria-labelledby="{concat('availAttributes',$id)}">
                                <xsl:for-each-group select="$allAttributes/descendant-or-self::tei:attDef" group-by="@ident">
                                    <xsl:sort select="current-grouping-key()"/>
                                    <li role="presentation">
                                        <xf:trigger class="btn add" appearance="minimal" ref=".[not({concat('@',current-grouping-key())})]">
                                            <xf:label><xsl:value-of select="current-grouping-key()"/></xf:label>
                                            <xf:insert ev:event="DOMActivate" context="." at="." origin="instance('i-attributeTemplate')//@*[name(.) = '{current-grouping-key()}']"></xf:insert>
                                        </xf:trigger>
                                    </li>
                                </xsl:for-each-group>
                            </ul>
                        </div>
                    </xsl:if>
                    <xsl:if test="$childElements/descendant-or-self::*:element[not(@classRef = 'true')] and $elementName != 'p'">
                        <div class="dropdown">
                            <button class="btn btn-default dropdown-toggle" type="button" id="{concat('availElements',$id)}" data-toggle="dropdown">
                                Available Elements <span class="caret"></span>
                            </button>
                            <ul class="dropdown-menu" role="menu" aria-labelledby="{concat('availElements',$id)}">
                                <xsl:for-each-group select="$childElements/descendant-or-self::*:element[not(@classRef = 'true')]" group-by="@ident">
                                    <xsl:sort select="current-grouping-key()"/>
                                    <li role="presentation">
                                        <xsl:variable name="refXpath">
                                            <xsl:variable name="elementMax">
                                                <xsl:choose>
                                                    <xsl:when test="tei:content/tei:sequence[@maxOccur]">
                                                        <xsl:value-of select="string(tei:content/tei:sequence[@maxOccur])"/>
                                                    </xsl:when>
                                                    <xsl:otherwise/>    
                                                </xsl:choose>
                                            </xsl:variable>
                                            <xsl:variable name="elementMin">
                                                <xsl:choose>
                                                    <xsl:when test="$elementRules/tei:content/tei:sequence[@minOccur]">
                                                        <xsl:value-of select="string($elementRules/tei:content/tei:sequence/@minOccur)"/>
                                                    </xsl:when>
                                                    <xsl:otherwise/>
                                                </xsl:choose>
                                            </xsl:variable>
                                            <xsl:choose>
                                                <xsl:when test="$elementRules/descendant::tei:content/tei:alternate"></xsl:when>
                                                <xsl:when test="$elementMax">
                                                    <xsl:choose>
                                                        <xsl:when test="$elementMax castable as xs:integer">
                                                            <xsl:choose>
                                                                <xsl:when test="xs:integer($elementMax) &gt; 1">
                                                                    <xsl:value-of select="concat('.[count(../tei:',current-grouping-key(),') &gt; ',$elementMax,')]')"/>
                                                                </xsl:when>
                                                                <xsl:otherwise><xsl:value-of select="'.'"/></xsl:otherwise>
                                                            </xsl:choose>
                                                        </xsl:when>
                                                        <xsl:otherwise>
                                                            <xsl:value-of select="'.'"/>
                                                        </xsl:otherwise>
                                                    </xsl:choose>
                                                </xsl:when>
                                                <xsl:otherwise>
                                                    <xsl:value-of select="'.'"/>
                                                </xsl:otherwise>
                                            </xsl:choose>
                                        </xsl:variable>
                                        <xf:trigger class="btn add" appearance="minimal" ref="{string($refXpath)}">
                                            <xf:label>
                                                <xsl:variable name="childRules" select="local:elementRules(current-grouping-key())"/>
                                                <xsl:choose>
                                                    <xsl:when test="$childRules/descendant-or-self::tei:gloss[@xml:lang = $formLang]">
                                                        <xsl:value-of select="$childRules/descendant-or-self::tei:gloss[@xml:lang = $formLang][1]"/>
                                                    </xsl:when>
                                                    <xsl:when test="$childRules/descendant-or-self::tei:gloss[@xml:lang = 'en']">
                                                        <xsl:value-of select="$childRules/descendant-or-self::tei:gloss[@xml:lang = 'en'][1]"/>
                                                    </xsl:when>
                                                    <xsl:otherwise>
                                                        <xsl:value-of select="current-grouping-key()"/>
                                                    </xsl:otherwise>
                                                </xsl:choose> 
                                            </xf:label>
                                            <xf:insert ev:event="DOMActivate" context="." at="." origin="instance('i-elementTemplate')//*[local-name(.) = '{current-grouping-key()}']" position="after"></xf:insert>    
                                        </xf:trigger>
                                    </li>
                                </xsl:for-each-group>
                            </ul>
                        </div>
                    </xsl:if>
                    <xsl:if test="$elementRules/descendant::tei:desc">
                        <span class="elementDesc hint">
                            <xsl:choose>
                                <xsl:when test="$elementRules/descendant::tei:desc[@xml:lang = $formLang]">
                                    <xsl:value-of select="$elementRules/descendant::tei:desc[@xml:lang = $formLang][1]"/>
                                </xsl:when>
                                <xsl:when test="$elementRules/descendant::tei:desc[@xml:lang = 'en']">
                                    <xsl:value-of select="$elementRules/descendant::tei:desc[@xml:lang = 'en'][1]"/>
                                </xsl:when>
                            </xsl:choose>
                        </span>
                    </xsl:if>
                </div>
                <xsl:if test="$allAttributes/descendant-or-self::tei:attDef">
                    <xsl:for-each-group select="$allAttributes/descendant-or-self::tei:attDef" group-by="@ident">
                        <xsl:variable name="attRef" select="concat('@', current-grouping-key())"/>
                        <xsl:choose>
                            <xsl:when test="descendant-or-self::tei:valItem">
                                <span class="attribute-group">
                                    <xf:select1 ref="{$attRef}" xmlns="http://www.w3.org/2002/xforms">
                                        <xf:label>
                                            <xsl:value-of select="current-grouping-key()"/>
                                        </xf:label>
                                        <xf:item>
                                            <xf:label>- Select -</xf:label>
                                            <xf:value/>
                                        </xf:item>
                                        <xsl:for-each select="descendant-or-self::tei:valItem">
                                            <xf:item>
                                                <xf:label>
                                                    <xsl:value-of select="@ident"/>
                                                </xf:label>
                                                <xf:value>
                                                    <xsl:value-of select="@ident"/>
                                                </xf:value>
                                            </xf:item>
                                        </xsl:for-each>
                                    </xf:select1>
                                    <xf:trigger appearance="minimal" class="btn remove"
                                        ref="{$attRef}">
                                        <xf:label/>
                                        <xf:delete ev:event="DOMActivate" ref="."/>
                                    </xf:trigger>
                                </span>
                            </xsl:when>
                            <xsl:otherwise>
                                <span class="attribute-group">
                                    <xf:input ref="{$attRef}">
                                        <xf:label>
                                            <xsl:value-of select="current-grouping-key()"/>
                                        </xf:label>
                                    </xf:input>
                                    <xf:trigger appearance="minimal" class="btn remove"
                                        ref="{$attRef}">
                                        <xf:label/>
                                        <xf:delete ev:event="DOMActivate" ref="."/>
                                    </xf:trigger>
                                </span>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:for-each-group>
                </xsl:if>
                <!-- Element entry -->
                <xsl:choose>
                    <xsl:when test="$elementName = 'p'">
                        <xf:textarea ref="." xmlns="http://www.w3.org/2002/xforms">
                            <xf:label><xsl:value-of select="$elementLabel"/></xf:label> 
                        </xf:textarea>
                    </xsl:when>
                    <xsl:when test="$childElements/descendant-or-self::*:element"/>
                    <xsl:otherwise>
                        <xsl:choose>
                            <xsl:when test="$elementName = ('p','desc','note','summary')">
                                <xf:textarea ref="." xmlns="http://www.w3.org/2002/xforms">
                                    <xf:label><xsl:value-of select="$elementLabel"/></xf:label> 
                                </xf:textarea>
                            </xsl:when>
                            <!--
                            <xsl:when test="$elementName = 'p' or $elementName = 'desc' or $elementRules/tei:global/descendant-or-self::tei:content/descendant-or-self::tei:textNode">
                                <xf:textarea ref="." xmlns="http://www.w3.org/2002/xforms">
                                    <xf:label><xsl:value-of select="$elementLabel"/></xf:label>
                                </xf:textarea>
                            </xsl:when>
                            -->
                            <xsl:otherwise>
                                <xf:input ref="." xmlns="http://www.w3.org/2002/xforms">
                                    <xf:label><xsl:value-of select="$elementName"/></xf:label>
                                </xf:input>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:otherwise>
                </xsl:choose>
                <!--  Include child elements inline, runs into nesting errors when generating -->
                <xsl:if test="$childElements/descendant-or-self::*:element[not(@classRef = 'true')] and $elementName != 'p'">
                    <xsl:for-each-group select="$childElements/descendant-or-self::*:element[not(@classRef = 'true')]" group-by="@ident">
                        <xsl:if test="$elementName != current-grouping-key() and not(contains($path,'current-grouping-key()'))">
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
