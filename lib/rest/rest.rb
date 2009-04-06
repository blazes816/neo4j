# This is a complete example and a spike of how RESTful Neo4j API would work

require 'rubygems'
require 'json'
require 'sinatra/base'
require 'neo4j'

# This mixin creates the following restful resources
# POST /[classname]/ Response: 201 with Location header to URI of the new resource representing created node
# GET /[classname]/[neo_id] Response: 200 with JSON representation of the node
# GET /[classname]/[neo_id]/[property_name] Response: 200 with JSON representation of the property of the node
# PUT /[classname]/[neo_id]/[property_name] sets the property with the content in the put request
#
# TODO delete and RESTful transaction (which will map to neo4j transactions)
#
module RestMixin

  #URL_REGEXP = Regexp.new '((http[s]?|ftp):\/)?\/?([^:\/\s]+)((\/\w+)*\/)([\w\-\.]+[^#?\s]+)(.*)?(#[\w\-]+)?$'
  URL_REGEXP = Regexp.new '((http[s]?|ftp):\/)?\/?([^:\/\s]+)((\/\w+)*\/)([\w\-\.]+[^#?\s]+)$'
  def _uri
    "#{_base_uri}/#{self.class.to_s}/#{self.neo_node_id}"
  end

  def _base_uri
    host = Sinatra::Application.host
    port = Sinatra::Application.port
    "http://#{host}:#{port}"
  end

  def self.included(c)
    classname = c.to_s

    Sinatra::Application.get("/#{classname}/:id/traverse") do
      content_type :json
      node = Neo4j.load(params[:id])
      return 404, "Can't find node with id #{params[:id]}" if node.nil?

      relation = params['relation']
      depth = params['depth']
      depth ||= 1
      uris = node.traverse.outgoing(relation.to_sym).depth(depth.to_i).collect{|node| node._uri}
      {'uri_list' => uris}.to_json
    end


    Sinatra::Application.get("/#{classname}/:id/:prop") do
      content_type :json
      node = Neo4j.load(params[:id])
      {params[:prop]=>node.get_property(params[:prop])}.to_json
    end


    Sinatra::Application.post("/#{classname}/:id/:rel") do
      content_type :json
      node = Neo4j.load(params[:id])
      rel = params[:rel]

      # does this relationship exist ?
      if !node.class.relations_info.keys.include?(rel.to_sym)
        return 409, "Can't add relation on '#{rel}' since it does not exist"
      end
      body = request.body.read
      data = JSON.parse(body)
      uri = data['uri']
      match = URL_REGEXP.match(uri)
      return 400, "Bad node uri '#{uri}'" if match.nil?
      to_clazz, to_node_id = match[6].split('/')

      other_node = Neo4j.load(to_node_id.to_i)
      return 400, "Unknown other node with id '#{to_node_id}'" if other_node.nil?

      if to_clazz != other_node.class.to_s
        return 400, "Wrong type id '#{to_node_id}' expected '#{to_clazz}' got '#{other_node.class.to_s}'"
      end

      rel_obj = node.instance_eval "#{rel}.new(other_node)" # TODO use send method instead

      return 400, "Can't create relationship to #{to_clazz}" if rel_obj.nil?
      
      # create URI
      redirect "/Relations/#{rel_obj.neo_relation_id.to_s}", 201 # created
    end


    Sinatra::Application.get("/Relations/:id") do
      content_type :json
      rel = Neo4j.load_relationship(params[:id])
      return 404, "Can't find relationship with id #{params[:id]}" if rel.nil?
      rel.props.to_json
    end

    Sinatra::Application.put("/#{classname}/:id/:prop") do
      content_type :json
      node = Neo4j.load(params[:id])
      property = params[:prop]
      body = request.body.read
      data = JSON.parse(body)
      value = data[property]
      return 409, "Can't set property #{property} with JSON data '#{body}'" if value.nil?
      node.set_property(property, value)
      200
    end

    Sinatra::Application.get("/#{classname}/:id") do
      content_type :json
      node = Neo4j.load(params[:id])
      return 404, "Can't find node with id #{params[:id]}" if node.nil?
      node.props.to_json
    end

    Sinatra::Application.post("/#{classname}") do
      p = c.new
      data = JSON.parse(request.body.read)
      p.update(data)
      redirect "/#{classname}/#{p.neo_node_id.to_s}", 201 # created
    end
  end
end


