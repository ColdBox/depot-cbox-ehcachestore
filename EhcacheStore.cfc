<!-----------------------------------------------------------------------
********************************************************************************
Copyright Since 2005 ColdBox Framework by Luis Majano and Ortus Solutions, Corp
www.coldbox.org | www.luismajano.com | www.ortussolutions.com
********************************************************************************

Author 	    :	Luis Majano
Description :
	The main interface for CacheBox object storages.
	A store is a physical counterpart to a cache, in which objects are kept, indexed and monitored.

----------------------------------------------------------------------->
<cfcomponent implements="cachebox.system.cache.store.IObjectStore" hint="The main interface for CacheBox object storages.">

	<cffunction name="init" access="public" output="false" returntype="EhcacheStore" hint="Constructor">
		<cfargument name="cacheProvider" type="any" required="true" hint="The associated cache provider as cachebox.system.cache.ICacheProvider" colddoc:generic="cachebox.system.cache.ICacheProvider"/>
		<cfset var managername='default_ehcache'>
		<cfset instance={
			cacheProvider=arguments.cacheProvider,
			manager=createObject("java","net.sf.ehcache.CacheManager"),
			config=arguments.cacheProvider.getConfiguration(),
			active=false,
			threadname=replacenocase("A"&createUUID(),'-','','all'),
			terracotta=false
		}>
		<cfif isDefined("instance.config.managername")>
			<cfset managername=instance.config.managername>
		</cfif>
		<cfset instance.managername=managername>
		<cfset var terracotta=''>
    	<cfset var config=''>
    	<cfset var cacheConfig=''>
    	<cfset configure(instance.config,instance.cacheProvider.getName())>
		<cfreturn this>
	</cffunction>
	
	<!--- flush --->
    <cffunction name="flush" output="false" access="public" returntype="void" hint="Flush the store to a permanent storage">
    	<cfif instance.active>
    		<cfset instance.cache.flush()>
    	</cfif>
    </cffunction>
	
	<!--- reap --->
    <cffunction name="reap" output="false" access="public" returntype="void" hint="Reap the storage, clean it from old stuff">
    	<!--- NOT NEEDED CAUSE EHCACHE WILL BE CLEAN OLD STUFF AUTOMATICALLY --->
    </cffunction>
	
	<!--- clearAll --->
    <cffunction name="clearAll" output="false" access="public" returntype="void" hint="Clear all elements of the store">
    	<cfif instance.active>
    		<cfset instance.cache.removeAll()>
    		<!---<cfset instance.indexer.clearAll()>--->
    	</cfif>
    </cffunction>
	
	<!--- getIndexer --->
	<cffunction name="getIndexer" access="public" returntype="any" output="false" hint="Get the store's pool metadata indexer structure" colddoc:generic="cachebox.system.cache.store.indexers.MetadataIndexer">
		<cfif instance.active>
			<cfreturn instance.indexer>
		</cfif>
		<cfreturn>
	</cffunction>
	
	<!--- getKeys --->
	<cffunction name="getKeys" output="false" access="public" returntype="any" hint="Get all the store's object keys array" colddoc:generic="Array">
		<cfif instance.active>
			<cftry>
				<cfset var keys=instance.cache.getKeysWithExpiryCheck().toArray()>
			<cfcatch>
				<cfreturn arrayNew(1)>
			</cfcatch>
			</cftry>
			<cfreturn keys>
		</cfif>
		<cfreturn arrayNew(1)>	
	</cffunction>
	
	<!--- lookup --->
	<cffunction name="lookup" access="public" output="false" returntype="any" hint="Check if an object is in the store">
		<cfargument name="objectKey" type="any" required="true" hint="The key of the object">
		<cfif instance.active>
			<cfset var element=instance.cache.get(objectKey)>
			<cfif isNull(element)>
				<cfreturn false>
			<cfelse>
				<cfreturn true>
			</cfif>
		</cfif>
		<cfreturn false>	
	</cffunction>
	
	<!--- get --->
	<cffunction name="get" access="public" output="false" returntype="any" hint="Get an object from the store">
		<cfargument name="objectKey" type="any" required="true" hint="The key of the object">
		<cfif instance.active>
			<cftry>
				<cfset var element=instance.cache.get(objectKey)>
			<cfcatch>
				<cfset instance.active=false>
				<!--- START THREAD --->
				<cfset terracottaThread()>
				<cfreturn>
			</cfcatch>
			</cftry>
			<cfif isNull(element)>
				<cfreturn ''>
			</cfif>
			<cftry>
				<!---<cfset instance.indexer.setObjectMetadataProperty(arguments.objectKey,"hits", instance.indexer.getObjectMetadataProperty(arguments.objectKey,"hits")+1)>
				<cfset instance.indexer.setObjectMetadataProperty(arguments.objectKey,"lastAccesed", now())>--->
			<cfcatch>
			</cfcatch>
			</cftry>
			<cfreturn deserializeJSON(element.getValue())>
		<cfelse>
			<cfreturn>
		</cfif>
	</cffunction>
	
	<!--- getQuiet --->
	<cffunction name="getQuiet" access="public" output="false" returntype="any" hint="Get an object from the store with no stat updates">
		<cfargument name="objectKey" type="any" required="true" hint="The key of the object">
		<cfif instance.active>
			<cfset var element=instance.cache.getQuiet(arguments.objectKey)>
			<cfif isNull(element)>
				<cfreturn>
			</cfif>
			<cfreturn deserializeJSON(element.getValue())>
		<cfelse>
			<cfreturn>
		</cfif>
	</cffunction>
	
	<!--- get --->
	<cffunction name="getTest" access="public" output="false" returntype="any" hint="Get an object from the store">
		<cftry>
			<cfset var element=instance.cache.get('test')>
		<cfcatch>
			<cfreturn false>
		</cfcatch>
		</cftry>
		<cfreturn true>
	</cffunction>
	
	<!--- getQuiet Element --->
	<cffunction name="getQuietElement" access="public" output="false" returntype="any" hint="Get an object from the store with no stat updates">
		<cfargument name="objectKey" type="any" required="true" hint="The key of the object">
		<cfif instance.active>
			<cfset var element=instance.cache.getQuiet(arguments.objectKey)>
			<cfif isNull(element)>
				<cfreturn>
			</cfif>
			<cfreturn element>
		<cfelse>
			<cfreturn>
		</cfif>
	</cffunction>
	
	<!--- expireObject --->
	<cffunction name="expireObject" output="false" access="public" returntype="void" hint="Mark an object for expiration">
		<cfargument name="objectKey" type="any"  required="true" hint="The object key">
		<cfif instance.active>
			<cfset var element=instance.cache.get(arguments.objectKey)>
			<cfif not isNull(element)>
				<cfset element.setTimeToLive(1)>
				<cfset element.setTimeToIdle(1)>
				<cfset instance.cache.put(element)>
				<!---<cfset instance.indexer.setObjectMetadataProperty(arguments.objectKey,"isExpired", true)>--->
			</cfif>
		</cfif>
	</cffunction>
	
	<!--- isExpired --->
    <cffunction name="isExpired" output="false" access="public" returntype="any" hint="Test if an object in the store has expired or not" colddoc:generic="Boolean">
    	<cfargument name="objectKey" type="any"  required="true" hint="The object key">
    	<cfif instance.active>
	    	<cfset var element=instance.cache.get(arguments.objectKey)>
	    	<cfif isNull(element)>
	    		<cfreturn true>
	    	<cfelse>
	    		<cfreturn element.isExpired()>
	    	</cfif>
		</cfif>
		<cfreturn true>
    </cffunction>
	
	<!--- Set an Object in the pool --->
	<cffunction name="set" access="public" output="false" returntype="void" hint="sets an object in the storage.">
		<cfargument name="objectKey" 			type="any"  required="true" hint="The object key">
		<cfargument name="object"				type="any" 	required="true" hint="The object to save">
		<cfargument name="timeout"				type="any"  required="false" default="" hint="Timeout in minutes">
		<cfargument name="lastAccessTimeout"	type="any"  required="false" default="" hint="Timeout in minutes">
		<cfargument name="extras" 				type="any" 	required="false" default="" hint="A map of extra name-value pairs"/>
		<cfif instance.active>
			<cfset var element=createObject("java","net.sf.ehcache.Element").init(arguments.objectKey,serializeJSON(object))>
			<cfif arguments.timeout neq ''>
				<cfset element.setTimetoLive(arguments.timeout*60)>
			</cfif>
			<cfset instance.cache.put(element)>
			<cfscript>
			
			
			// Save the object's metadata
			//instance.indexer.setObjectMetadata(arguments.objectKey, metaData);
		</cfscript>
		</cfif>
	</cffunction>
	
	<!--- Clear an object from the pool --->
	<cffunction name="clear" access="public" output="false" returntype="any" hint="Clears an object from the storage pool" colddoc:generic="Boolean">
		<cfargument name="objectKey" type="any"  required="true" hint="The object key">
		<cfif instance.active>
			<cfset instance.cache.remove(arguments.objectKey)>
			<!---<cfset instance.indexer.clear( arguments.objectKey )>--->
		</cfif>
	</cffunction>

	<!--- Get the size of the pool --->
	<cffunction name="getSize" access="public" output="false" returntype="any" hint="Get the store's size" colddoc:generic="numeric">
		<cfif instance.active>
			<cfreturn instance.cache.getSize()>
		<cfelse>
			<cfreturn 0>
		</cfif>
	</cffunction>
	
	<!--- If Thread had initialized cache, it will be call this method --->
	<cffunction name="activate" access="public" output="false" returntype="void" hint="If terracotta is ready, activate ehcache">
		<cfset instance.active=true>
	</cffunction>
	
	<!--- Will check, weather a terracotta server is available --->
	<cffunction name="checkTerracotta" access="public" output="false" returntype="boolean">
		<cfargument name="url" type="string" required="true" hint="comma separeted list of url:port">
		<cfset var response=''>
		<cfloop list="#arguments.url#" index="item">
			<cfhttp url="#trim(item)#" method="GET" timeout="2" result="response">
			</cfhttp>
			<cfif structCount(response.responseheader) gt 0>
				<cfreturn true>
			</cfif>
		</cfloop>
		<cfreturn false>
	</cffunction>
	
	<!--- PRIVATE METHODS --->
	
	<!--- configure Store --->
	<cffunction name="configure" access="private" output="false" returntype="void" hint="Configure Cachemanager and cache instance">
		<cfset var fields = "hits,timeout,lastAccessTimeout,created,lastAccesed,isExpired">
		<cfset instance.manager=instance.manager.getCacheManager(instance.managername)>
		<cfif isNull(instance.manager)>
			<cfset cacheConfig=createObject("java","net.sf.ehcache.config.CacheConfiguration").init("default",10000).eternal(false)>
	    	<cfif structKeyExists(instance.config,'objectDefaultTimeout')>
	    		<cfset cacheConfig.setTimeToLiveSeconds(instance.config.objectDefaultTimeout*60)>
	    	</cfif>
			<cfif structKeyExists(instance.config,'objectDefaultLastAccessTimeout')>
	    		<cfset cacheConfig.setTimeToIdleSeconds(instance.config.objectDefaultLastAccessTimeout*60)>
	    	</cfif>
			<cfif structKeyExists(instance.config,'evictionPolicy')>
	    		<cfset cacheConfig.memoryStoreEvictionPolicy(instance.config.evictionPolicy)>
	    	</cfif>
			<cfif structKeyExists(instance.config,'maxObjects')>
	    		<cfset cacheConfig.maxElementsInMemory(instance.config.maxObjects)>
	    	</cfif>
	    	<cfset config=createObject("java","net.sf.ehcache.config.Configuration").init()>
			<cfset config.setName(instance.managername)>
			<cfif structKeyExists(instance.config,'terracotta') and instance.config.terracotta neq '' and checkTerracotta(instance.config.terracotta)>
				<cfif checkTerracotta(instance.config.terracotta)>
					<cfset terracotta=createObject("java","net.sf.ehcache.config.TerracottaClientConfiguration").init()>
					<cfset terracotta.setUrl(instance.config.terracotta)>
					<cfset terracotta.setRejoin(true)>
					<cfset config.addTerracottaconfig(terracotta)>
					<cfset terracottaconfig=createObject("java","net.sf.ehcache.config.TerracottaConfiguration").init()>
					<cfset nonstopconfig=createObject("java","net.sf.ehcache.config.NonstopConfiguration").init().timeoutMillis(500)>
					<cfset nonstopconfig.setImmediateTimeout(true)>
					<cfset timeoutbehavior=createObject("java","net.sf.ehcache.config.TimeoutBehaviorConfiguration").init()>
					<cfset timeoutbehavior.setType('exception')>
					<cfset nonstopconfig.addTimeoutBehavior(timeoutbehavior)>
					<cfset terracottaconfig.addNonstop(nonstopconfig)>
					<cfset cacheconfig.terracotta(terracottaconfig)>
					<cfset config.addDefaultCache(cacheconfig)>
					<cfset instance.terracotta=true>
					<cfset instance.manager=createObject("java","net.sf.ehcache.CacheManager").init(config)>
				<cfelse>
				</cfif>
			<cfelse>
				<cfset config.addDefaultCache(cacheconfig)>
				<cfset instance.manager=createObject("java","net.sf.ehcache.CacheManager").init(config)>
				<cfset instance.active=true>
			</cfif>
			<cfset instance.cache=instance.manager.addCacheIfAbsent(instance.cacheprovider.getName())>
			<cfset instance.indexer=createObject("component","cachebox.system.cache.store.indexers.MetadataIndexer").init(fields,this)>
		<cfelse>
			<cfset instance.cache=instance.manager.addCacheIfAbsent(instance.cacheprovider.getName())>
			<cfset instance.active=true>
			<cfset instance.indexer=createObject("component","cachebox.system.cache.store.indexers.EhcachedataIndexer").init(fields,this)>
		</cfif>
	</cffunction>
	
	<!--- startThread --->
	<cffunction name="terracottaThread" access="private" output="false">
		<cfif not instance.active and structKeyExists(instance.config,'terracotta') and instance.config.terracotta neq ''>
			<cfthread action="run" name="#instance.threadname#" >
				<cfsetting requesttimeout="86400">
				<cfset Thread.store=this>
				<cfset Thread.terracotta=instance.config.terracotta>
				<cfset Thread.doLoop=true>
				<cftry>
				<cfloop condition="Thread.doLoop">
					<cfsleep time="5000">
					<cfif Thread.store.checkTerracotta(Thread.terracotta)>
						
						<cfif Thread.store.getTest()>
							<cfset Thread.doLoop=false>
							<cfset Thread.store.activate()>
						</cfif>
					</cfif>
				</cfloop>
				<cfcatch>
				</cfcatch>
				</cftry>
			</cfthread>
		</cfif>
	</cffunction>
	
	
	
</cfcomponent>