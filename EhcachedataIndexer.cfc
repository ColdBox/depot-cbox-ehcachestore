<!-----------------------------------------------------------------------
********************************************************************************
Copyright Since 2005 ColdBox Framework by Luis Majano and Ortus Solutions, Corp
www.coldbox.org | www.luismajano.com | www.ortussolutions.com
********************************************************************************

Author     :	Luis Majano
Date        :	11/14/2007
Description :
	This is a utility object that helps object stores keep their elements indexed
	and stored nicely.  It is also a nice way to give back metadata results.
	
----------------------------------------------------------------------->
<cfcomponent output="false" 
			 hint="This is a utility object that helps object stores keep their items indexed and pretty"
			 extends="cachebox.system.cache.store.indexers.MetadataIndexer">

<!------------------------------------------- CONSTRUCTOR ------------------------------------------->
	
	<cffunction name="init" access="public" output="false" returntype="EhcachedataIndexer" hint="Constructor">
		<cfargument name="fields" 	required="true" hint="The list or array of fields to bind this index on"/>
		<cfargument name="store" 	required="true" hint="The associated storage"/>
		<cfscript>
			super.init(arguments.fields);
			
			// store storage reference
			instance.store = arguments.store;
			
			return this;
		</cfscript>
	</cffunction>
	
<!------------------------------------------- PUBLIC ------------------------------------------->
	
	<!--- getFields --->
	<cffunction name="getFields" access="public" returntype="any" output="false" hint="Get the bounded fields list">
    	<cfreturn instance.fields>
    </cffunction>
	
	<!--- setFields --->
    <cffunction name="setFields" output="false" access="public" returntype="void" hint="Override the constructed metadata fields this index is binded to">
    	<cfargument name="fields" type="any" required="true" hint="The list or array of fields to bind this index on"/>
		<cfset instance.fields=arguments.fields>
    </cffunction>

	<!--- objectExists --->
    <cffunction name="objectExists" output="false" access="public" returntype="any" hint="Check if the metadata entry exists for an object">
    	<cfargument name="objectKey" type="any" required="true" hint="The key of the object">
		<cfreturn instance.store.lookup(arguments.objectKey)>
	</cffunction>
	
	<!--- getObjectMetadata --->
	<cffunction name="getObjectMetadata" access="public" returntype="any" output="false" hint="Get a metadata entry for a specific entry. Exception if key not found">
		<cfargument name="objectKey" type="any" required="true" hint="The key of the object">
		
	</cffunction>
	
	<!--- getObjectMetadataProperty --->
	<cffunction name="getObjectMetadataProperty" access="public" returntype="any" output="false" hint="Get a specific metadata property for a specific entry">
		<cfargument name="objectKey" type="any" required="true" hint="The key of the object">
		<cfargument name="property"  type="any" required="true" hint="The property of the metadata to retrieve, must exist in the binded fields or exception is thrown">
		<cfset var element=''>
		<cfset validateField(arguments.property)>
		<cfif isInstanceOf(arguments.objectKey,'net.sf.ehcache.Element')>
			<cfset element = arguments.objectKey>
		<cfelse>
			<cfif not objectExists(arguments.objectKey)>
				<cfreturn>
			</cfif>
			<cfset element=instance.store.getQuietElement(arguments.objectKey)>
		</cfif>
		<cfswitch expression="#arguments.property#">
			<cfcase value="hits">
				<cfreturn element.getHitCount()>
			</cfcase>
			<cfcase value="timeout">
				<cfreturn element.getTimeToLive()/60>
			</cfcase>
			<cfcase value="lastAccessTimeout">
				<cfreturn (element.getTimeToIdle()/60)>
			</cfcase>
			<cfcase value="created">
				<cfreturn dateAdd('s',element.getCreationTime()/1000,createDateTime(1970,1,1,0,0,0))>
			</cfcase>
			<cfcase value="lastAccesed">
				<cfreturn dateAdd('s',element.getLastAccessTime()/1000,createDateTime(1970,1,1,0,0,0))>
			</cfcase>
			<cfcase value="isExpired">
				<cfreturn element.isExpired()>
			</cfcase>
		</cfswitch>
	</cffunction>
	
	<!--- setObjectMetadata --->
	<cffunction name="setObjectMetadata" access="public" returntype="void" output="false" hint="Set the metadata entry for a specific entry">
		<cfargument name="objectKey" type="any" required="true" hint="The key of the object">
		<cfargument name="metadata"  type="any" required="true" hint="The metadata structure to store for the cache entry">
		<!--- IGNORE, CAUSE EHCACHE HAS AN OWN STATISTICS --->
	</cffunction>
	
	<!--- getSize --->
    <cffunction name="getSize" output="false" access="public" returntype="any" hint="Get the size of the elements indexed">
    	<cfreturn instance.store.getSize()>
    </cffunction>
	
	<!--- getSortedKeys --->
    <cffunction name="getSortedKeys" output="false" access="public" returntype="any" hint="Get an array of sorted keys for this indexer according to parameters">
    	<cfargument name="property"  type="any" required="true" hint="The property field to sort the index on. It must exist in the binded fields or exception"/>
		<cfargument name="sortType"  type="any" required="false" default="text" hint="The sort ordering: numeric, text or textnocase"/>
		<cfargument name="sortOrder" type="any" required="false" default="asc" hint="The sort order: asc or desc"/>
		<cfreturn instance.store.getKeys()>
    </cffunction>
	
	<!--- getPoolMetadata --->
    <cffunction name="getPoolMetadata" output="false" access="public" returntype="any" hint="Get the entire pool reference">
    	<cfset var data=structNew()>
    	<cfset var element=''>
    	<cfset var keys=instance.store.getKeys()>
    	<cfloop array="#keys#" index="item">
    		<cfset element=instance.store.getQuietElement(item)>
    		<cfset data[item]=structNew()>
    		<cfset data[item].timeout=getObjectMetadataProperty(element,'timeout')>
    		<cfset data[item].hits=getObjectMetadataProperty(element,'hits')>
    		<cfset data[item].lastAccessTimeout=getObjectMetadataProperty(element,'lastAccessTimeout')>
    		<cfset data[item].created=getObjectMetadataProperty(element,'created')>
    		<cfset data[item].lastAccesed=getObjectMetadataProperty(element,'lastAccesed')>
    		<cfset data[item].isExpired=getObjectMetadataProperty(element,'isExpired')>
    	</cfloop>
    	<cfreturn data>
    </cffunction>

<!------------------------------------------- PRIVATE ------------------------------------------>


	<!--- validateField --->
    <cffunction name="validateField" output="false" access="private" returntype="void" hint="Validate or thrown an exception on an invalid field">
    	<cfargument name="target" type="any" required="true" hint="The target field to validate"/>
		<cfif not listFindNoCase(instance.fields, arguments.target)>
			<cfthrow message="Invalid index field property"
					 detail="The property sent: #arguments.target# is not valid. Valid fields are #instance.fields#"
					 type="EhcachedataIndexer.InvalidFieldException" >
		</cfif>
    </cffunction>

</cfcomponent>