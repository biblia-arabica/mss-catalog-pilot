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
    <!-- Global Variables -->
    <!-- XForm configuration document, default is config.xml -->
    <xsl:variable name="configDoc" select="document($config)"/>
    <!-- Form languge; default is en -->
    <xsl:variable name="formLang">
        <xsl:choose>
            <xsl:when test="$configDoc//formLang[. != '']">
                <xsl:value-of select="$configDoc//formLang"/>
            </xsl:when>
            <xsl:otherwise>en</xsl:otherwise>
        </xsl:choose>
    </xsl:variable>
    <!-- For use with the eXist application, establishes the full path to the application -->
    <xsl:variable name="app-root" select="'http://localhost:8080/exist/apps/mssXForms/forms'"/>
    
    <xsl:output name="xform" encoding="UTF-8" method="xhtml" indent="yes" omit-xml-declaration="yes" xml:space="preserve" xpath-default-namespace="http://www.w3.org/1999/xhtml"/>
    <xsl:output name="tei" encoding="UTF-8" method="xml" indent="yes" xpath-default-namespace="http://www.tei-c.org/ns/1.0"/>

    <!-- Helper functions -->
    <!-- 
        Check local and global schemas for element rules 
        @param: elementName - name of element to lookup in the schema
        @param: subform  - name of subform, for locating the correct local schema customizations
    -->    
    <xsl:function name="local:elementRules">
        <xsl:param name="elementName"/>
        <xsl:param name="subform"/>
        <xsl:variable name="localSchemaDoc" select="document($configDoc//subform[@formName = $subform]/localSchema/@src)"/>
        <xsl:variable name="globalSchemaDoc" select="document($configDoc//subform[@formName = $subform]/globalSchema/@src)"/>
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
    <!-- 
        Find all child elements for selected element, check local schema rules first, then global 
        @param: elementName - name of element to lookup in the schema
        @param: subform  - name of subform, for locating the correct local schema customizations
    -->
    <xsl:function name="local:childElements">
        <xsl:param name="elementName"/>
        <xsl:param name="subform"/>
        <xsl:variable name="elementRules" select="local:elementRules($elementName, $subform)"/>
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
                                    <xsl:copy-of select="local:resolveMacroSpec(current-grouping-key(),$subform)"></xsl:copy-of> 
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:copy-of select="local:resolveClassRef(current-grouping-key(),$subform)"></xsl:copy-of>
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
    <!-- 
        Find all child elements using memberOf references within an element specification. 
        @param: elementName - name of element to lookup in the schema
        @param: subform  - name of subform, for locating the correct local schema customizations
    -->
    <xsl:function name="local:resolveClassRef">
        <xsl:param name="className"/>
        <xsl:param name="subform"/>
        <xsl:variable name="localSchemaDoc" select="document($configDoc//subform[@formName = $subform]/localSchema/@src)"/>
        <xsl:variable name="globalSchemaDoc" select="document($configDoc//subform[@formName = $subform]/globalSchema/@src)"/>
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
                                <xsl:copy-of select="local:resolveClassRef($subClassName,$subform)"/>
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
                            <xsl:copy-of select="local:resolveClassRef($subClassName,$subform)"/>
                        </xsl:when>
                        <xsl:otherwise><xsl:value-of select="name(.)"/></xsl:otherwise>
                    </xsl:choose>
                </xsl:for-each>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>
    <!-- 
        Find all child elements using macroSpec references within an element specification. 
        @param: elementName - name of element to lookup in the schema
        @param: subform  - name of subform, for locating the correct local schema customizations
    -->
    <xsl:function name="local:resolveMacroSpec">
        <xsl:param name="macroSpec"/>
        <xsl:param name="subform"/>
        <xsl:variable name="localSchemaDoc" select="document($configDoc//subform[@formName = $subform]/localSchema/@src)"/>
        <xsl:variable name="globalSchemaDoc" select="document($configDoc//subform[@formName = $subform]/globalSchema/@src)"/>
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
                                <xsl:copy-of select="local:resolveClassRef($subClassName,$subform)"/>
                            </xsl:when>
                            <xsl:when test="self::tei:classRef">
                                <xsl:variable name="subClassName" select="@key"/>
                                <xsl:copy-of select="local:resolveClassRef($subClassName,$subform)"/>
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
                            <xsl:copy-of select="local:resolveClassRef($subClassName,$subform)"/>
                        </xsl:when>
                        <xsl:when test="self::tei:classRef">
                            <xsl:variable name="subClassName" select="@key"/>
                            <xsl:copy-of select="local:resolveClassRef($subClassName, $subform)"/>
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
 <!-- 
        Find all associated attributes of the specified element 
        @param: elementName - name of element to lookup in the schema
        @param: subform  - name of subform, for locating the correct local schema customizations
    -->
    <xsl:function name="local:classSpecAtt">
        <xsl:param name="className"/>
        <xsl:param name="subform"/>
        <xsl:variable name="localSchemaDoc" select="document($configDoc//subform[@formName = $subform]/localSchema/@src)"/>
        <xsl:variable name="globalSchemaDoc" select="document($configDoc//subform[@formName = $subform]/globalSchema/@src)"/>
        <xsl:variable name="localClasses" select="$localSchemaDoc//descendant-or-self::tei:classSpec[@ident = $className]"/>
        <xsl:variable name="globalClasses" select="$globalSchemaDoc//descendant-or-self::tei:classSpec[@ident = $className]"/>
        <rules xmlns="http://www.tei-c.org/ns/1.0">
            <local>
                <xsl:for-each select="$localClasses/descendant-or-self::tei:attList/descendant-or-self::tei:attDef">
                    <xsl:copy-of select="."/>
                </xsl:for-each>
                <xsl:variable name="memberOf" select="$localClasses/descendant-or-self::tei:classes/tei:memberOf[starts-with(@key, 'att.')]/@key"/>
                <xsl:for-each select="$memberOf">
                    <xsl:copy-of select="local:classSpecAtt($memberOf, $subform)"/>
                </xsl:for-each>
            </local>
            <global>
                <xsl:for-each select="$globalClasses/descendant-or-self::tei:attList/descendant-or-self::tei:attDef">
                    <xsl:copy-of select="."/>
                </xsl:for-each>
                <xsl:variable name="memberOf" select="$globalClasses/descendant-or-self::tei:classes/tei:memberOf[starts-with(@key, 'att.')]/@key"/>
                <xsl:for-each select="$memberOf">
                    <xsl:copy-of select="local:classSpecAtt($memberOf,$subform)"/>
                </xsl:for-each>
            </global>
        </rules>
    </xsl:function>
    <!-- 
        Find all associated attributes of the specified element 
        @param: elementName - name of element to lookup in the schema
        @param: subform  - name of subform, for locating the correct local schema customizations
    -->
    <xsl:function name="local:allAttributes">
        <xsl:param name="elementName"/>
        <xsl:param name="subform"/>
        <xsl:variable name="elementRules" select="local:elementRules($elementName, $subform)"/>
        <xsl:variable name="childAtt" select="$elementRules/descendant-or-self::tei:attList/descendant-or-self::tei:attDef"/>
        <xsl:variable name="memberOfAtt">
            <xsl:for-each select="$elementRules/descendant-or-self::tei:classes/tei:memberOf[starts-with(@key, 'att.')]">
                <xsl:choose>
                    <xsl:when test=".[@mode='delete'][ancestor-or-self::tei:local]"></xsl:when>
                    <xsl:when test=".[@mode='change'][ancestor-or-self::tei:local]"><xsl:copy-of select="local:classSpecAtt(.[@mode='change'][ancestor-or-self::tei:local][1]/@key,$subform)"/></xsl:when>
                    <xsl:when test=".[@mode='opt'][ancestor-or-self::tei:local]"><xsl:copy-of select="local:classSpecAtt(.[@mode='opt'][ancestor-or-self::tei:local][1]/@key,$subform)"/></xsl:when>
                    <xsl:when test=".[@mode='add'][ancestor-or-self::tei:local]"><xsl:copy-of select="local:classSpecAtt(.[@mode='add'][ancestor-or-self::tei:local][1]/@key,$subform)"/></xsl:when>
                    <xsl:when test=".[@mode='replace'][ancestor-or-self::tei:local]"><xsl:copy-of select="local:classSpecAtt(.[@mode='replace'][ancestor-or-self::tei:local][1]/@key,$subform)"/></xsl:when>
                    <xsl:otherwise><xsl:copy-of select=".[1]"/></xsl:otherwise>
                </xsl:choose>
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
        <!-- 
            Output Main form navigation page
            Load either template, or find record
            List sections in order
            Allow paging? 
        -->
        <xsl:result-document href="{$configDoc//formName}.xhtml" format="xform">
            <xsl:call-template name="formMainPage"/>
        </xsl:result-document>
        <!-- Output an XForm for each subform listed in the config.xml subforms section -->
        <xsl:for-each select="$configDoc//subform">
            <xsl:variable name="formName" select="@formName"/>
            <xsl:result-document href="{$formName}.xhtml" format="xform">
                <xsl:call-template name="xform">
                    <xsl:with-param name="subform" select="."/>
                </xsl:call-template>
            </xsl:result-document>
        </xsl:for-each>
        <!-- Output controlled values for each custom schema -->
        <xsl:for-each select="$configDoc//subform">
            <xsl:variable name="formName" select="@formName"/>
            <xsl:result-document href="{$formName}-controlledValues.xml" format="tei">
                <xsl:call-template name="controlledValues">
                    <xsl:with-param name="subform" select="$formName"/>
                </xsl:call-template>
            </xsl:result-document>
        </xsl:for-each>
        <!-- WS:NOTE Not needed any more? Test
        <xsl:result-document href="controlledValues.xml" format="tei">
            <xsl:call-template name="controlledValues"/>
        </xsl:result-document>
        -->
        <!-- Output an XForm with all possible elements, used to add elements -->
        <xsl:result-document href="elementTemplate.xml" format="tei">
            <xsl:call-template name="elementTemplate"/>
        </xsl:result-document>
        <!-- Output an XForm with all possible attributes, used to add attributes -->
        <xsl:result-document href="attributesTemplate.xml" format="tei">
            <xsl:call-template name="attributesTemplate"/>
        </xsl:result-document>
    </xsl:template>
    
    <xsl:template name="formMainPage">
        <xsl:text disable-output-escaping="yes">&lt;!DOCTYPE html&gt;</xsl:text>
        <html xmlns="http://www.w3.org/1999/xhtml" 
            xmlns:xi="http://www.w3.org/2001/XInclude"
            xmlns:ev="http://www.w3.org/2001/xml-events" 
            xmlns:tei="http://www.tei-c.org/ns/1.0"
            xmlns:xf="http://www.w3.org/2002/xforms"
            xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <head>
                <title>
                    <xsl:value-of select="$configDoc//formTitle"/>
                </title>
                <meta name="author" content="{$configDoc//formAuthor}"/>
                <meta name="description" content="{$configDoc//formDesc}"/>
                <link rel="stylesheet" type="text/css" href="resources/bootstrap/css/bootstrap.min.css"/>
                <link rel="stylesheet" type="text/css" href="resources/css/xforms.css"/>
                <link href="resources/jquery-ui/jquery-ui.min.css" rel="stylesheet"/>
                <script type="text/javascript" src="resources/js/jquery.min.js"/>
                <script type="text/javascript" src="resources/bootstrap/js/bootstrap.min.js"/>
                <xf:model id="m-mss">
                    <xf:instance id="i-rec">
                        <data></data>
                    </xf:instance>
                    <xf:instance id="i-upload">
                        <attachment xsi:type="xsd:anyURI"></attachment>
                    </xf:instance>
                    <xf:instance id="i-search">
                        <data></data>
                    </xf:instance>
                    <xf:instance id="i-search-results">
                        <data></data>
                    </xf:instance>
                    <xf:instance id="i-selected">
                        <data>
                        </data>
                    </xf:instance>
                    <xf:instance id="i-selectTemplate">
                        <data>
                            <template name="Generic Template" src="/forms/templates/template.xml"></template>
                            <template name="MSS Additions Template" src="/forms/templates/mss-additions-template.xml"></template>
                            <template name="MSS Hand Template" src="/forms/templates/mss-hand-template.xml"></template>
                            <template name="MSS History Template" src="/forms/templates/mss-history-template.xml"></template>
                            <template name="MSS Layout Template" src="/forms/templates/mss-layout-template.xml"></template>
                        </data>
                    </xf:instance>
                    <xf:instance id="i-subforms">
                        <data>
                            <xsl:for-each select="$configDoc//subform">
                                <subform formName="{@formName}"></subform>
                            </xsl:for-each>
                        </data>
                    </xf:instance>
                    <xf:submission id="s-load-template" 
                        method="post" ref="instance('i-selected')" 
                        replace="instance" 
                        instance="i-rec" 
                        serialization="none" mode="synchronous">
                        <xf:resource value="concat('services/get-rec.xql?template=true&amp;path=',instance('i-selected'))"/>
                        <xf:message level="modeless" ev:event="xforms-submit-done"> Data Loaded! </xf:message>
                        <xf:message level="modeless" ev:event="xforms-submit-error"> Submit error. </xf:message>
                    </xf:submission>
                    <xf:submission id="s-search-saved" 
                        method="post" ref="instance('i-search')" 
                        replace="instance" 
                        instance="i-search-results" 
                        serialization="none" mode="synchronous" action="services/get-rec.xql?search=true" >
<!--                        <xf:resource value="concat('services/get-rec.xql?template=true&amp;path=',instance('i-selected'))"/>-->
                        <xf:message level="modeless" ev:event="xforms-submit-done"> Data Loaded! </xf:message>
                        <xf:message level="modeless" ev:event="xforms-submit-error"> Submit error. </xf:message>
                    </xf:submission>
                    <xf:submission id="s-browse-saved" 
                        method="post" ref="instance('i-search')" 
                        replace="instance" 
                        instance="i-search-results" 
                        serialization="none" mode="synchronous" action="services/get-rec.xql?search=true&amp;view=all" >
                        <xf:message level="modeless" ev:event="xforms-submit-error"> Submit error. </xf:message>
                    </xf:submission>
                </xf:model>
                    
                    <!-- s-load-template
                        <xf:submission id="upload" ref="instance('i-rec')" method="xml-urlencoded-post" replace="all" action="load.xql"> 
                            <xf:message level="modeless" ev:event="xforms-submit-error"> Submit error. </xf:message> 
                        </xf:submission> 
                        <xf:submission id="fileSearch" ref="instance('i-search')" method="xml-urlencoded-post" replace="all" action="search.xql"> 
                            <xf:message level="modeless" ev:event="xforms-submit-error"> Submit error. </xf:message> 
                        </xf:submission>
                    --> 
            </head>
            <body>
                <div class="section xforms">
                    <!-- Form title -->
                    <h1><xsl:value-of select="$configDoc//formTitle"/></h1> 
                    <!-- Form description -->
                    <xsl:if test="$configDoc//formDesc != ''">
                        <p><xsl:value-of select="$configDoc//formDesc"/></p>
                    </xsl:if>
                    <div class="row tabbable">
                        <!-- Menu items, subforms -->
                        <ul class="nav nav-pills nav-stacked col-md-3">
                            <li>
                                <xf:trigger appearance="minimal">
                                    <xf:label>Main Page &#160;</xf:label>
                                    <xf:action ev:event="DOMActivate">
                                        <xf:toggle case="view-main-entry"/>
                                    </xf:action>
                                </xf:trigger>
                            </li>
                            <xsl:for-each select="$configDoc//subform">
                                <li> 
                                    <xf:trigger appearance="minimal" ref="instance('i-subforms')//*:subform[@formName = '{string(@formName)}']">
                                        <xf:label><xsl:value-of select="string(@formName)"/> &#160;</xf:label>
                                        <xf:action ev:event="DOMActivate">
                                            <xf:toggle case="view-data-entry"/>
                                            <xf:load if="@selected != 'true'" show="embed" targetid="subform" resource="{concat('form.xq?form=forms/',@formName,'.xhtml')}"/>
                                            <xf:unload if="@selected = 'true'" targetid="subform"/>
                                            <xf:setvalue ref="@selected" value=". != 'true'"/>
                                        </xf:action>
                                    </xf:trigger>
                                </li>
                            </xsl:for-each>
                        </ul>
                        <div class="tab-content col-md-9">
                            <xf:switch id="edit" class="tab-panel">
                                <xf:case id="view-main-entry" selected="true()">
                                    <h2>Find your data</h2>
                                    <!-- Save for later -->
                                    <!-- Load an existing template -->
                                    <div class="fileLoading">
                                        <xf:select1 xmlns="http://www.w3.org/2002/xforms" ref="instance('i-selected')">
                                            <xf:label>Search saved TEI records</xf:label>
                                            <xf:itemset ref="instance('i-selectTemplate')//*:template">
                                                <xf:label ref="@name"/>
                                                <xf:value ref="@src"/>
                                            </xf:itemset>
                                        </xf:select1>
                                        <xf:submit class="btn btn-default" submission="s-load-template" appearance="minimal">
                                            <xf:label> Load selected record </xf:label>
                                        </xf:submit>
                                    </div>
                                    <div class="fileLoading">
                                        <xf:input ref="instance('i-search')" incremental="true">
                                            <xf:label>Select a saved TEI XML record: </xf:label>
                                        </xf:input>
                                        <xf:submit class="btn btn-default" submission="s-search-saved" appearance="minimal">
                                            <xf:label> Search </xf:label>
                                        </xf:submit>
                                        <xf:submit class="btn btn-default" submission="s-browse-saved" appearance="minimal">
                                            <xf:label> Browse </xf:label>
                                        </xf:submit>
                                    </div>
                                    <div class="fileLoading">
                                        <xf:select1 xmlns="http://www.w3.org/2002/xforms" ref="instance('i-selected')">
                                            <xf:label>Select a TEI XML record to edit</xf:label>
                                            <xf:itemset ref="instance('i-search-results')//*:record">
                                                <xf:label ref="@name"/>
                                                <xf:value ref="@src"/>
                                            </xf:itemset>
                                        </xf:select1>
                                        <xf:submit class="btn btn-default" submission="s-load-search" appearance="minimal">
                                            <xf:label> Load selected record </xf:label>
                                        </xf:submit>
                                    </div>
                                    <!--
                                        <div class="fileLoading">
                                            <xf:upload ref="instance('i-upload')" mediatype="application/xml" incremental="true">
                                                <xf:label>Upload a TEI XML record: </xf:label>
                                                <xf:trigger>
                                                    <xf:label>Submit</xf:label>
                                                    <xf:setvalue ev:event="DOMActivate" ref="instance('i-upload')//*:attachment" value="transform(instance('content'), serialize(instance('serialize')), true())"/>
                                                </xf:trigger>
                                            </xf:upload>
                                        </div>
                                    -->
                                    <h3>Preview XML</h3>
                                    <xf:group>
                                        <xf:output value="serialize(instance('i-rec'))"/>
                                    </xf:group>
                                </xf:case>
                                <xf:case id="view-data-entry">
                                    <xf:group id="subform"/>
                                </xf:case>
                            </xf:switch>
                        </div>
                    </div>
                </div>
            </body>
        </html>
    </xsl:template>
    
    <xsl:template name="xform">
        <xsl:param name="subform"/>
        <xsl:variable name="template" select="document($subform/xmlTemplate/@src)"/>  
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
                <link rel="stylesheet" type="text/css" href="resources/bootstrap/css/bootstrap.min.css"/>
                <link rel="stylesheet" type="text/css" href="resources/css/xforms.css"/>
                <link href="resources/jquery-ui/jquery-ui.min.css" rel="stylesheet"/>
                <script type="text/javascript" src="resources/js/jquery.min.js"/>
                <script type="text/javascript" src="resources/bootstrap/js/bootstrap.min.js"/>
                <xf:model id="m-mss">
                    <!-- Create instances -->
                    <xf:instance id="i-rec" src="forms/templates/{$subform/xmlTemplate/@src}"/>
                    <xf:instance id="i-template" src="forms/templates/template.xml"/>
                    <xf:instance id="i-ctr-vals" src="forms/templates/{string($subform/@formName)}-controlledValues.xml"/>
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
                    <xsl:variable name="xpath" select="string($subform/@xpath)"/>
                    <xsl:variable name="subsequence">
                        <xsl:evaluate xpath="$xpath" context-item="$template"/>
                    </xsl:variable>
                    <xsl:for-each select="$subsequence/element()">
                        <xsl:variable name="elementPath" select="replace(replace(replace(replace(path(.), 'Q\{http://www.tei-c.org/ns/1.0\}', 'tei:'), 'tei:TEI', '/'), '\[[0-9]+\]', ''), '///', '//')"/>
                        <xsl:variable name="elementName" select="local-name(.)"/>
                        <xsl:call-template name="xformElementUI">
                            <xsl:with-param name="elementName" select="$elementName"/>
                            <xsl:with-param name="subform" select="$subform/@formName"/>
                            <xsl:with-param name="path"/>
                            <xsl:with-param name="min"/>
                            <xsl:with-param name="max"/>
                            <xsl:with-param name="level" select="'root'"/>
                        </xsl:call-template>
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
        <xsl:param name="subform"/>
        <xsl:variable name="localSchemaDoc" select="document($configDoc//subform[@formName = $subform]/localSchema/@src)"/>
        <!-- Build a template with all the controlled values, referenced by the xforms model -->
        <xsl:for-each select="$localSchemaDoc/child::*">
            <!-- <xsl:call-template name="buildXFormsElement"/> -->
            <TEI xmlns="http://www.tei-c.org/ns/1.0" xml:id="controlledValues" xml:lang="en">
                <xsl:apply-templates mode="controlledValues"/>
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
            <!-- WS:NOTE this does not include local schemas, so if new elements are added they will not be picked up, 
                I do not foresee this as an issue, but will re-evaluate as needed -->
            <xsl:variable name="globalSchemaDoc" select="document($configDoc//subform[1]/globalSchema/@src)"/>
            <xsl:for-each-group select="$globalSchemaDoc//descendant-or-self::tei:elementSpec" group-by="@ident">
                <xsl:sort select="current-grouping-key()"/>
                <xsl:element name="{current-grouping-key()}" namespace="http://www.tei-c.org/ns/1.0"/>
            </xsl:for-each-group>
        </TEI>
    </xsl:template>

    <xsl:template name="attributesTemplate">
        <xsl:variable name="globalSchemaDoc" select="document($configDoc//globalSchema[1]/@src)"/>
        <xsl:variable name="localSchemaDoc">
            <xsl:for-each select="$configDoc//subform">
                <xsl:copy-of select="document(globalSchema[1]/@src)"/>
            </xsl:for-each>
        </xsl:variable> 
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
 
    <xsl:template name="xformElementUI">
        <xsl:param name="elementName"/>
        <xsl:param name="subform"/>
        <xsl:param name="path"/>
        <xsl:param name="min"/>
        <xsl:param name="max"/>
        <xsl:param name="level"/>
        
        <xsl:variable name="elementRules" select="local:elementRules($elementName,$subform)"/>
        <xsl:variable name="allAttributes" select="local:allAttributes($elementName,$subform)"/>
        <xsl:variable name="childElements" select="local:childElements($elementName,$subform)"/>
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
        <!-- This does not work as I want it to. templates must have all the parts pre coded. ?
        <xsl:if test="$level = 'root'">
            <xf:trigger appearance="minimal" class="btn remove inline" xmlns="http://www.w3.org/2002/xforms" ref=".[not(child::tei:{$elementName})] ">
                <xf:label>Add <xsl:value-of select="$elementLabel"/></xf:label>
                <xf:insert ev:event="DOMActivate" context="." at="." origin="instance('i-elementTemplate')//*[local-name(.) = '{$elementName}']" position="after"></xf:insert>
            </xf:trigger>
        </xsl:if>
        -->
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
                                                <xsl:variable name="childRules" select="local:elementRules(current-grouping-key(),$subform)"/>
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
                                <xsl:when test="$formLang != ''">
                                    <xsl:choose>
                                        <xsl:when test="$elementRules/descendant::tei:desc[@xml:lang = $formLang]">
                                            <xsl:value-of select="$elementRules/descendant::tei:desc[@xml:lang = $formLang][1]"/>
                                        </xsl:when>
                                        <xsl:when test="$elementRules/descendant::tei:desc[@xml:lang = 'en']">
                                            <xsl:value-of select="$elementRules/descendant::tei:desc[@xml:lang = 'en'][1]"/>
                                        </xsl:when>
                                    </xsl:choose>
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
                                <xsl:with-param name="subform" select="$subform"/>
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
