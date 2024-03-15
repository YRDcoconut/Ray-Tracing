// filename: cw1_student.uclcg
// tabGroup: Coursework
// thumbnail: cw1_thumb.png
// displayname: Coursework 1 - 2023/2024
// shortDescription: Coursework 1 - Ray Tracing
// author: None
// isHidden: false
function setup()
{
	UI = {};
	UI.tabs = [];
	UI.titleLong = 'Ray Tracer';
	UI.titleShort = 'RayTracerSimple';
	UI.numFrames = 100000;
	UI.maxFPS = 24;
	UI.renderWidth = 1600;
	UI.renderHeight = 800;

	UI.tabs.push(
		{
		visible: true,
		type: `x-shader/x-fragment`,
		title: `RaytracingDemoFS - GL`,
		id: `RaytracingDemoFS`,
		initialValue: ` 
//#define SOLUTION_CYLINDER_AND_PLANE
//#define SOLUTION_SHADOW
//#define SOLUTION_REFLECTION_REFRACTION
//#define SOLUTION_FRESNEL

//#define SOLUTION_POLYTOPE

precision highp float;
uniform ivec2 viewport; 

struct PointLight {
	vec3 position;
	vec3 color;
};

struct Material {
	vec3  diffuse;
	vec3  specular;
	float glossiness;
	float reflection;
	float refraction;
	float ior;
};

struct Sphere {
	vec3 position;
	float radius;
	Material material;
};

struct Plane {
	vec3 normal;
	float d;
	Material material;
};

struct Cylinder {
	vec3 position;
	vec3 direction;  
	float radius;
	Material material;
};


const int polytope_size = 10; //
struct Polytope {
	vec3 normals[polytope_size];
	float ds[polytope_size];
	Material material;
};


const int lightCount = 2;
const int sphereCount = 3;
const int planeCount = 1;
const int cylinderCount = 2;
const int booleanCount = 2; 

struct Scene {
	vec3 ambient;
	PointLight[lightCount] lights;
	Sphere[sphereCount] spheres;
	Plane[planeCount] planes;
	Cylinder[cylinderCount] cylinders;
	Polytope polytope; 
};

struct Ray {
	vec3 origin;
	vec3 direction;
};

// Contains all information pertaining to a ray/object intersection
struct HitInfo {
	bool hit;
	float t;
	vec3 position;
	vec3 normal;
	Material material;
	bool enteringPrimitive;
};

HitInfo getEmptyHit() {
	return HitInfo(
		false, 
		0.0, 
		vec3(0.0), 
		vec3(0.0), 
		Material(vec3(0.0), vec3(0.0), 0.0, 0.0, 0.0, 0.0),
		false);
}

// Sorts the two t values such that t1 is smaller than t2
void sortT(inout float t1, inout float t2) {
	// Make t1 the smaller t
	if(t2 < t1)  {
		float temp = t1;
		t1 = t2;
		t2 = temp;
	}
}

// Tests if t is in an interval
bool isTInInterval(const float t, const float tMin, const float tMax) {
	return t > tMin && t < tMax;
}

// Get the smallest t in an interval.
bool getSmallestTInInterval(float t0, float t1, const float tMin, const float tMax, inout float smallestTInInterval) {
  
	sortT(t0, t1);

	// As t0 is smaller, test this first
	if(isTInInterval(t0, tMin, tMax)) {
		smallestTInInterval = t0;
		return true;
	}

	// If t0 was not in the interval, still t1 could be
	if(isTInInterval(t1, tMin, tMax)) {
		smallestTInInterval = t1;
		return true;
	}  

	// None was
	return false;
}

HitInfo intersectSphere(const Ray ray, const Sphere sphere, const float tMin, const float tMax) {
              
    vec3 to_sphere = ray.origin - sphere.position;
  
    float a = dot(ray.direction, ray.direction);
    float b = 2.0 * dot(ray.direction, to_sphere);
    float c = dot(to_sphere, to_sphere) - sphere.radius * sphere.radius;
    float D = b * b - 4.0 * a * c;
    if (D > 0.0)
    {
	   float t0 = (-b - sqrt(D)) / (2.0 * a);
		float t1 = (-b + sqrt(D)) / (2.0 * a);
      
      	float smallestTInInterval;
      	if(!getSmallestTInInterval(t0, t1, tMin, tMax, smallestTInInterval)) {
          return getEmptyHit();
        }
      
      	vec3 hitPosition = ray.origin + smallestTInInterval * ray.direction;      
		
		//Checking if we're inside the sphere by checking if the ray's origin is inside. If we are, then the normal 
		//at the intersection surface points towards the center. Otherwise, if we are outside the sphere, then the normal 
		//at the intersection surface points outwards from the sphere's center. This is important for refraction.
       vec3 normal = 
           length(ray.origin - sphere.position) < sphere.radius + 0.001? 
           -normalize(hitPosition - sphere.position): 
      		normalize(hitPosition - sphere.position);      
		
		//Checking if we're inside the sphere by checking if the ray's origin is inside,
		// but this time for IOR bookkeeping. 
		//If we are inside, set a flag to say we're leaving. If we are outside, set the flag to say we're entering.
		//This is also important for refraction.
		 bool enteringPrimitive = 
          	length(ray.origin - sphere.position) < sphere.radius + 0.001 ? 
           false:
		    true;

        return HitInfo(
          	true,
          	smallestTInInterval,
          	hitPosition,
          	normal,
          	sphere.material,
			enteringPrimitive);
    }
    return getEmptyHit();
}

HitInfo intersectPlane(const Ray ray,const Plane plane, const float tMin, const float tMax) {
#ifdef SOLUTION_CYLINDER_AND_PLANE
	//Check if the ray is parallel to the plane.
	//If so, there won't be any intersection.
	float value = dot(plane.normal, ray.direction);
	//The line connecting any point on the plane to the point of intersection
	//is perpendicular to the plane's normal vector.
	//Use this principle to generate the equation of 't'
	if (abs(value) > 0.0001)
	{
		float t = (plane.d - dot(plane.normal, ray.origin)) / value;
		if (!isTInInterval(t, tMin, tMax)) 
		{
			return getEmptyHit();
		}
		vec3 hitPosition = ray.origin + t * ray.direction;
		
		vec3 normal = 
          	value > 0.0 ? //The angle between the direction of ray and the normal vector of the plane is acute
          	-normalize(plane.normal): 
      		normalize(plane.normal);
						
		bool enteringPrimitive = 
          	value > 0.0 ? 
          	false:
		    true;
				
		return HitInfo(
			true,
			t,
			hitPosition,
			normal,
			plane.material,
			enteringPrimitive);
	}
#endif  
	return getEmptyHit();
}

float lengthSquared(vec3 x) {
	return dot(x, x);
}

HitInfo intersectCylinder(const Ray ray, const Cylinder cylinder, const float tMin, const float tMax) {
#ifdef SOLUTION_CYLINDER_AND_PLANE
	//The vector formed by the line connecting a point on the axis of the cylinder to the point of intersection,
	//cross-producted with the normal vector of the cylinder, has a magnitude equal to the radius of the cylinder.
	//Use this principle to generate the a binary linear equation in terms of t.
	vec3 to_cylinder = ray.origin - cylinder.position;
	vec3 n_axis = normalize(cylinder.direction);   
	
	float a = lengthSquared(ray.direction) - pow(dot(ray.direction, n_axis), 2.0);
	float b = 2.0 * (dot(to_cylinder, ray.direction) - dot(ray.direction, n_axis) * dot(to_cylinder, n_axis));
	float c = lengthSquared(to_cylinder) - cylinder.radius * cylinder.radius - pow(dot(to_cylinder, n_axis), 2.0);
	float D = b * b - 4.0 * a * c;
	
	if (D > 0.0)
   {
	  float t0 = (-b - sqrt(D)) / (2.0 * a);
	  float t1 = (-b + sqrt(D)) / (2.0 * a);
	   
	   float smallestTInInterval;
      	if(!getSmallestTInInterval(t0, t1, tMin, tMax, smallestTInInterval)) {
          return getEmptyHit();
        }
      
      	vec3 hitPosition = ray.origin + smallestTInInterval * ray.direction;
	   
	   //Calculate normals
	   //The vector formed by the line connecting a point on the axis of the cylinder to the point of intersection, 
	   //project it onto the axis of the cylinder
	    vec3 to_hitPosition = hitPosition - cylinder.position;
	    float projection = dot(to_hitPosition, n_axis);
	   //Calculate the endpoint of the projected vector.
	   //The line connecting this point and the intersection point is perpendicular to the axis of the cylinder
	    vec3 axis_origin = cylinder.position + projection * n_axis; 
	   //Similarly, check if the ray origin is inside the cylinder. 	   
	    vec3 normal = 
           length(ray.origin - axis_origin) < cylinder.radius + 0.001 ?
			   -normalize(hitPosition - axis_origin):
	   		 normalize(hitPosition - axis_origin);
	   
	    bool enteringPrimitive = 
          	length(ray.origin - axis_origin) < cylinder.radius + 0.001 ? 
           false:
		    true;
			 	    
        return HitInfo(
          	true,
          	smallestTInInterval,
          	hitPosition,
          	normal,
          	cylinder.material,
			enteringPrimitive);
    }
#endif  
    return getEmptyHit();
}

bool inside(const vec3 position, const Sphere sphere) {
	return length(position - sphere.position) < sphere.radius;
}

HitInfo intersectPolytope(const Ray ray, const Polytope polytope, const float tMin, const float tMax) {
	
#ifdef SOLUTION_POLYTOPE
	Plane polyPlanes[polytope_size]; //Polytope planes
	//Initialize polytope Hitinfo
	HitInfo polyHitinfo = getEmptyHit();
	polyHitinfo.t = tMax;
	
	// Intersect Ray with one plane of the polytope
	for(int i=0; i < polytope_size; ++i){
		polyPlanes[i].normal = polytope.normals[i];
		polyPlanes[i].d = polytope.ds[i];
		polyPlanes[i].material = polytope.material;
		HitInfo currentHitInfo = intersectPlane(ray, polyPlanes[i], tMin, tMax);
		if (currentHitInfo.t > polyHitinfo.t){
			continue;
		}
		// Half-Space Test
		bool isInPolytope = true;
		
		for(int j=0; j < polytope_size; ++j){
			vec3 normal = polytope.normals[j];
			float d = polytope.ds[j];
			if (dot(normal, currentHitInfo.position) - d > 0.001){
				isInPolytope = false;
				break;
			}
		}
		if (isInPolytope){
			polyHitinfo = currentHitInfo;
		}
	}
	if (!polyHitinfo.hit){
		return getEmptyHit(); //The Ray dosen't intersect with the plane
	}
	return polyHitinfo;	
#else
	// Put your Polytope intersection code in the #ifdef above!
#endif
	return getEmptyHit();
}

uniform float time;

HitInfo getBetterHitInfo(const HitInfo oldHitInfo, const HitInfo newHitInfo) {
	if(newHitInfo.hit)
  		if(newHitInfo.t < oldHitInfo.t)  // No need to test for the interval, this has to be done per-primitive
          return newHitInfo;
  	return oldHitInfo;
}

HitInfo intersectScene(const Scene scene, const Ray ray, const float tMin, const float tMax) {
	HitInfo bestHitInfo;
	bestHitInfo.t = tMax;
	bestHitInfo.hit = false;
	
	bestHitInfo = getBetterHitInfo(bestHitInfo, intersectPolytope(ray, scene.polytope, tMin, tMax));

	for (int i = 0; i < planeCount; ++i) {
		bestHitInfo = getBetterHitInfo(bestHitInfo, intersectPlane(ray, scene.planes[i], tMin, tMax));
	}
	for (int i = 0; i < sphereCount; ++i) {
		bestHitInfo = getBetterHitInfo(bestHitInfo, intersectSphere(ray, scene.spheres[i], tMin, tMax));
	}
	for (int i = 0; i < cylinderCount; ++i) {
		bestHitInfo = getBetterHitInfo(bestHitInfo, intersectCylinder(ray, scene.cylinders[i], tMin, tMax));
	}
	
	return bestHitInfo;
}

vec3 shadeFromLight(
  const Scene scene,
  const Ray ray,
  const HitInfo hit_info,
  const PointLight light)
{ 
  vec3 hitToLight = light.position - hit_info.position;
  
  vec3 lightDirection = normalize(hitToLight);
  vec3 viewDirection = normalize(hit_info.position - ray.origin);
  vec3 reflectedDirection = reflect(viewDirection, hit_info.normal);
  float diffuse_term = max(0.0, dot(lightDirection, hit_info.normal));
  float specular_term  = pow(max(0.0, dot(lightDirection, reflectedDirection)), hit_info.material.glossiness);

#ifdef SOLUTION_SHADOW
  Ray shadowRay;
  shadowRay.origin = hit_info.position;
  shadowRay.direction = lightDirection;
  HitInfo shadowHitInfo = intersectScene(scene, shadowRay, 0.001, 100000.0);
  float range = sqrt(lengthSquared(hitToLight));
  float visibility = 
    shadowHitInfo.hit && shadowHitInfo.t > 0.0 && shadowHitInfo.t < range ?
    0.0 : 1.0;
#else
  // Put your shadow test here
  float visibility = 1.0;
#endif
  return 	visibility * 
    		light.color * (
    		specular_term * hit_info.material.specular +
      		diffuse_term * hit_info.material.diffuse);
}

vec3 background(const Ray ray) {
  // A simple implicit sky that can be used for the background
  return vec3(0.2) + vec3(0.8, 0.6, 0.5) * max(0.0, ray.direction.y);
}

// It seems to be a WebGL issue that the third parameter needs to be inout instea dof const on Tobias' machine
vec3 shade(const Scene scene, const Ray ray, inout HitInfo hitInfo) {
	
  	if(!hitInfo.hit) {
  		return background(ray);
  	}
  
    vec3 shading = scene.ambient * hitInfo.material.diffuse;
    for (int i = 0; i < lightCount; ++i) {
        shading += shadeFromLight(scene, ray, hitInfo, scene.lights[i]); 
    }
    return shading;
}


Ray getFragCoordRay(const vec2 frag_coord) {
  	float sensorDistance = 1.0;
  	vec2 sensorMin = vec2(-1, -0.5);
  	vec2 sensorMax = vec2(1, 0.5);
  	vec2 pixelSize = (sensorMax- sensorMin) / vec2(viewport.x, viewport.y);
  	vec3 origin = vec3(0, 0, sensorDistance);
    vec3 direction = normalize(vec3(sensorMin + pixelSize * frag_coord, -sensorDistance));  
  
  	return Ray(origin, direction);
}

float fresnel(const vec3 viewDirection, const vec3 normal, const float sourceIOR, const float destIOR) {
#ifdef SOLUTION_FRESNEL
	//Schlick's approximation:
	/*float R0 = pow(((sourceIOR - destIOR) / (sourceIOR + destIOR)), 2.0);
	float cosTheta = dot(normal, -viewDirection);
	return R0 + (1.0 - r0) * pow((1.0 - cosTheta), 1.8);*/
	
	//As the angle between the normal and the ray direction decreases, 
	//the refraction weight increases while the reflection weight decreases
	float cosTheta = max(0.0, dot(normal, -viewDirection));
	return 1.0 - cosTheta;
#else
  	// Put your code to compute the Fresnel effect in the ifdef above
	return 1.0;
#endif
}

vec3 colorForFragment(const Scene scene, const vec2 fragCoord) {
      
    Ray initialRay = getFragCoordRay(fragCoord);  
  	HitInfo initialHitInfo = intersectScene(scene, initialRay, 0.001, 10000.0);  
  	vec3 result = shade(scene, initialRay, initialHitInfo);
	
  	Ray currentRay;
  	HitInfo currentHitInfo;
  	
  	// Compute the reflection
  	currentRay = initialRay;
  	currentHitInfo = initialHitInfo;
  	
  	// The initial strength of the reflection
  	float reflectionWeight = 1.0;
	
	// The initial medium is air
  	float currentIOR = 1.0;
	
    float sourceIOR = 1.0;
	float destIOR = 1.0;
  	
  	const int maxReflectionStepCount = 2;
  	for(int i = 0; i < maxReflectionStepCount; i++) {
      
      if(!currentHitInfo.hit) break;
      
#ifdef SOLUTION_REFLECTION_REFRACTION
		reflectionWeight *= currentHitInfo.material.reflection;
		if (reflectionWeight < 0.001) break;
#else
      // Put your reflection weighting code in the ifdef above
#endif
      
#ifdef SOLUTION_FRESNEL
		if (!currentHitInfo.hit || reflectionWeight == 0.){
			break;
		}
		if (currentHitInfo.enteringPrimitive){
			sourceIOR = 1.0;
			destIOR = currentHitInfo.material.ior;
			currentIOR = destIOR;
		}
		else{
			sourceIOR = currentIOR;
			destIOR = 1.0;
		}
		reflectionWeight *= fresnel(currentRay.direction, currentHitInfo.normal, sourceIOR, destIOR);
#else
      // Replace with Fresnel code in the ifdef above
      reflectionWeight *= 0.5;
#endif
      
      Ray nextRay;
#ifdef SOLUTION_REFLECTION_REFRACTION
		 nextRay.origin = currentHitInfo.position;
		 nextRay.direction = reflect(currentRay.direction, currentHitInfo.normal);
		 //nextRay.direction = -normalize(currentRay.direction) + 2.0 * currentHitInfo.normal * dot(currentHitInfo.normal, normalize(currentRay.direction));
#else
	// Put your code to compute the reflection ray in the ifdef above
#endif
      currentRay = nextRay;
      
      currentHitInfo = intersectScene(scene, currentRay, 0.001, 10000.0);      
            
      result += reflectionWeight * shade(scene, currentRay, currentHitInfo);
    }
  
  	// Compute the refraction
  	currentRay = initialRay;  
  	currentHitInfo = initialHitInfo;
   
  	// The initial strength of the refraction.
  	float refractionWeight = 1.0;
  
  	const int maxRefractionStepCount = 2;
  	for(int i = 0; i < maxRefractionStepCount; i++) {
      
#ifdef SOLUTION_REFLECTION_REFRACTION
		 refractionWeight *= currentHitInfo.material.refraction;
		 if (refractionWeight < 0.001) break;
#else
      // Put your refraction weighting code in the ifdef above
      refractionWeight *= 0.5;      
#endif

#ifdef SOLUTION_FRESNEL
		if (!currentHitInfo.hit || refractionWeight == 0.){
			break;
		}
		if (currentHitInfo.enteringPrimitive){
			sourceIOR = 1.0;
			destIOR = currentHitInfo.material.ior;
			currentIOR = destIOR;
		}
		else{
			sourceIOR = currentIOR;
			destIOR = 1.0;
		}
		//reflection weight + refraction weight = 1
		refractionWeight *= (1.0 - fresnel(currentRay.direction, currentHitInfo.normal, sourceIOR, destIOR)); 
		
		
#else
      // Put your Fresnel code in the ifdef above 
#endif      

      Ray nextRay;


#ifdef SOLUTION_REFLECTION_REFRACTION
		//Detecting whether the ray is entering the primitive.
		destIOR = currentHitInfo.enteringPrimitive ?
			currentHitInfo.material.ior:
			sourceIOR;
		
		float eta = currentIOR / destIOR;
		float cosIn = dot(currentHitInfo.normal, normalize(currentRay.direction));
		float k = 1.0 + eta * eta * (cosIn * cosIn - 1.0);
		
		//Estimate whether there is total internal reflection. If k < 0, total internal reflection occur
		//and sourceIOR and currentIOR will stay the same.
		if (k < 0.0){
			//nextRay.direction = normalize(normalize(currentRay.direction) - 2.0 * cosIn * currentHitInfo.normal);
			nextRay.direction = reflect(currentRay.direction, currentHitInfo.normal);
		}
		else{	
			nextRay.direction = refract(currentRay.direction, currentHitInfo.normal, eta);
			//Update IOR for next refraction
			sourceIOR = currentIOR;
			currentIOR = destIOR;
		}	
		nextRay.origin = currentHitInfo.position + 0.01 * nextRay.direction;
		
		currentRay = nextRay;
#else
  
	// Put your code to compute the reflection ray and track the IOR in the ifdef above
#endif
      currentHitInfo = intersectScene(scene, currentRay, 0.001, 10000.0);
          
      result += refractionWeight * shade(scene, currentRay, currentHitInfo);
      
      if(!currentHitInfo.hit) break;
    }
  return result;
}

Material getDefaultMaterial() {
  return Material(vec3(0.3), vec3(0), 0.0, 0.0, 0.0, 0.0);
}

Material getPaperMaterial() {
  return Material(vec3(0.7, 0.7, 0.7), vec3(0, 0, 0), 5.0, 0.0, 0.0, 0.0);
}

Material getPlasticMaterial() {
	return Material(vec3(0.9, 0.3, 0.1), vec3(1.0), 10.0, 0.9, 0.0, 0.0);
}

Material getGlassMaterial() {
	return Material(vec3(0.0), vec3(0.0), 5.0, 1.0, 1.0, 1.5);
}

Material getSteelMirrorMaterial() {
	return Material(vec3(0.1), vec3(0.3), 20.0, 0.8, 0.0, 0.0);
}

Material getMetaMaterial() {
	return Material(vec3(0.1, 0.2, 0.5), vec3(0.3, 0.7, 0.9), 20.0, 0.8, 0.0, 0.0);
}

vec3 tonemap(const vec3 radiance) {
  const float monitorGamma = 2.0;
  return pow(radiance, vec3(1.0 / monitorGamma));
}

void clearShape(inout Polytope shape) {
	/*
		clear the polytope
	*/
	for (int i = 0; i < polytope_size; i++) {
		shape.normals[i] = vec3(0.0);
		shape.ds[i] = 0.0;
	}
}
void loadCube(float size, inout Polytope cube) {
	/* 
		load a cube to test intersection code
		
		NOTE THAT:
		Here the cube is loaded in a specific order => (top, bottom, front, back, left, right).
		You should load the diamond in a similar way.
	*/
	cube.normals[0] = vec3(0, 1, 0); // TOP
	cube.normals[1] = vec3(0, -1, 0); // BOTTOM
	cube.normals[2] = vec3(0, 0, 1); // FRONT
	cube.normals[3] = vec3(0, 0, -1); // BACK
	cube.normals[4] = vec3(-1, 0, 0); // LEFT
	cube.normals[5] = vec3(1, 0, 0); // RIGHT
	for (int i = 0; i < 6; i++) {
		cube.ds[i] = size; // the size of the cube
	}
}

void loadDiamond(float height, float width, float slope, inout Polytope diamond, inout bool isSuccessful) {
	/*
		Implement your code to load a diamond at origin (0.0, 0.0, 0.0)
		
		Input Arguments:
			height: the distance between the top plane and the bottom plane
			width: the edge length of the square in the middle of the diamond
			slope: the angle between the 8 side planes and the X-Z plane (in radians)
			
		Inout Arguments:
			diamond: the polytope that you need to modify
			isSuccessful: true if diamond is loaded successfully, false otherwise
		
		NOTE THAT:
		Please load the diamond, i.e., 10 planes, in this order:
		(top, bottom, upper-front, upper-back, upper-left, upper-right, lower-front, lower-back, lower-left, lower-right)
	*/
		
#ifdef SOLUTION_POLYTOPE
	diamond.normals[0] = vec3(0, 1, 0);	//top
	diamond.normals[1] = vec3(0, -1, 0);	//bottom
	diamond.normals[2] = vec3(0, cos(slope), sin(slope));	//upper-front
	diamond.normals[3] = vec3(0, cos(slope), -sin(slope));	//upper-back
	diamond.normals[4] = vec3(-sin(slope), cos(slope), 0);	//upper-left
	diamond.normals[5] = vec3(sin(slope), cos(slope), 0);	//upper-right
	diamond.normals[6] = vec3(0, -cos(slope), sin(slope));	//lower-front
	diamond.normals[7] = vec3(0, -cos(slope), -sin(slope));	//lower-back
	diamond.normals[8] = vec3(-sin(slope), -cos(slope), 0);	//lower-left
	diamond.normals[9] = vec3(sin(slope), -cos(slope), 0);	//lower-right
	for (int i = 0; i < 2; i++){
		diamond.ds[i] = height / 2.;
	}
	for (int i = 2; i < 10; i++){
		diamond.ds[i] = (width / 2.) * sin(slope);
	}
	isSuccessful = true;
#else
	// Put your code in the above solution block
	// don't forget to set it true in your implementation!
	isSuccessful = false;
#endif
}

void main() {
	// Setup scene
	Scene scene;
	scene.ambient = vec3(0.12, 0.15, 0.2);
	scene.lights[0].position = vec3(5, 15, -5);
	scene.lights[0].color    = 0.5 * vec3(0.9, 0.5, 0.1);

	scene.lights[1].position = vec3(-15, 5, 2);
	scene.lights[1].color    = 0.5 * vec3(0.1, 0.3, 1.0);
	
	// Primitives
	bool specialScene = false;
	
#if defined(SOLUTION_POLYTOPE)
	specialScene = true;
#endif
	
	if (specialScene) {
		// Polytope diamond scene
		float slope = radians(70.0);
		bool isDiamond = false;
		loadDiamond(8.0, 4.37, slope, scene.polytope, isDiamond);
		
		if (!isDiamond) {
			clearShape(scene.polytope);
			loadCube(3.0, scene.polytope);
		}
		
		// rotate the diamond along the Y axis
		mat3 rot;
		float speed = 10.0;
		float theta = radians(speed * time);
		
		// Three angles that might be tested for marking
		 //float theta = radians(0.0);
		// float theta = radians(30.0);
		// float theta = radians(45.0);
		
		// rotating
		rot[0] = vec3(cos(theta), 0, -sin(theta));
		rot[1] = vec3(0, 1, 0);
		rot[2] = vec3(sin(theta), 0, cos(theta));
		for (int i = 0; i < polytope_size; i++) {
			scene.polytope.normals[i] = rot * scene.polytope.normals[i];
		}
		
		// push the origin-centered diamond along the Z axis to display it properly
		float at_z = 15.0;
		// push the upper part
		scene.polytope.ds[2] = scene.polytope.ds[2] - cos(theta) * sin(slope) * at_z;
		scene.polytope.ds[3] = scene.polytope.ds[3] + cos(theta) * sin(slope) * at_z;
		scene.polytope.ds[4] = scene.polytope.ds[4] - sin(theta) * sin(slope) * at_z;
		scene.polytope.ds[5] = scene.polytope.ds[5] + sin(theta) * sin(slope) * at_z;
		if (isDiamond) {
			// push the lower part
			scene.polytope.ds[6] = scene.polytope.ds[6] - cos(theta) * sin(slope) * at_z;
			scene.polytope.ds[7] = scene.polytope.ds[7] + cos(theta) * sin(slope) * at_z;
			scene.polytope.ds[8] = scene.polytope.ds[8] - sin(theta) * sin(slope) * at_z;
			scene.polytope.ds[9] = scene.polytope.ds[9] + sin(theta) * sin(slope) * at_z;
		}
		
		if (isDiamond) scene.polytope.material = getGlassMaterial();
		else scene.polytope.material = getMetaMaterial();
		
		// add floor
		scene.planes[0].normal            		= normalize(vec3(0, 1.0, 0));
		scene.planes[0].d              			= -4.5;
		scene.planes[0].material				= getSteelMirrorMaterial();
		if (isDiamond) {
			// add some primitives to play around
			scene.cylinders[0].position            	= vec3(-15, 1, -26);
			scene.cylinders[0].direction            = normalize(vec3(-2, 2, -1));
			scene.cylinders[0].radius         		= 1.5;
			scene.cylinders[0].material				= getPaperMaterial();

			scene.cylinders[1].position            	= vec3(15, 1, -26);
			scene.cylinders[1].direction            = normalize(vec3(2, 2, -1));
			scene.cylinders[1].radius         		= 1.5;
			scene.cylinders[1].material				= getPlasticMaterial();
		}
	}
	else {
		// normal scene
		scene.spheres[0].position            	= vec3(10, -5, -16);
		scene.spheres[0].radius              	= 6.0;
		scene.spheres[0].material 				= getPaperMaterial();

		scene.spheres[1].position            	= vec3(-7, -2, -13);
		scene.spheres[1].radius             	= 4.0;
		scene.spheres[1].material				= getPlasticMaterial();

		scene.spheres[2].position            	= vec3(0, 0.5, -5);
		scene.spheres[2].radius              	= 2.0;
		scene.spheres[2].material   			= getGlassMaterial();

		scene.planes[0].normal            		= normalize(vec3(0, 1.0, 0));
		scene.planes[0].d              			= -4.5;
		scene.planes[0].material				= getSteelMirrorMaterial();

		scene.cylinders[0].position            	= vec3(-1, 1, -26);
		scene.cylinders[0].direction            = normalize(vec3(-2, 2, -1));
		scene.cylinders[0].radius         		= 1.5;
		scene.cylinders[0].material				= getPaperMaterial();

		scene.cylinders[1].position            	= vec3(4, 1, -5);
		scene.cylinders[1].direction            = normalize(vec3(1, 4, 1));
		scene.cylinders[1].radius         		= 0.4;
		scene.cylinders[1].material				= getPlasticMaterial();
	}

	// Compute color for fragment
	gl_FragColor.rgb = tonemap(colorForFragment(scene, gl_FragCoord.xy));
	gl_FragColor.a = 1.0;

}
`,
		description: ``,
		wrapFunctionStart: ``,
		wrapFunctionEnd: ``
	});

	UI.tabs.push(
		{
		visible: false,
		type: `x-shader/x-vertex`,
		title: `RaytracingDemoVS - GL`,
		id: `RaytracingDemoVS`,
		initialValue: `attribute vec3 position;
    uniform mat4 modelViewMatrix;
    uniform mat4 projectionMatrix;
  
    void main(void) {
        gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
    }
`,
		description: ``,
		wrapFunctionStart: ``,
		wrapFunctionEnd: ``
	});

	 return UI; 
}//!setup

var gl;
function initGL(canvas) {
	try {
		gl = canvas.getContext("experimental-webgl");
		gl.viewportWidth = canvas.width;
		gl.viewportHeight = canvas.height;
	} catch (e) {
	}
	if (!gl) {
		alert("Could not initialise WebGL, sorry :-(");
	}
}

function getShader(gl, id) {
	var shaderScript = document.getElementById(id);
	if (!shaderScript) {
		return null;
	}

	var str = "";
	var k = shaderScript.firstChild;
	while (k) {
		if (k.nodeType == 3) {
			str += k.textContent;
		}
		k = k.nextSibling;
	}

	var shader;
	if (shaderScript.type == "x-shader/x-fragment") {
		shader = gl.createShader(gl.FRAGMENT_SHADER);
	} else if (shaderScript.type == "x-shader/x-vertex") {
		shader = gl.createShader(gl.VERTEX_SHADER);
	} else {
		return null;
	}

    console.log(str);
	gl.shaderSource(shader, str);
	gl.compileShader(shader);

	if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
		alert(gl.getShaderInfoLog(shader));
		return null;
	}

	return shader;
}

function RaytracingDemo() {
}

RaytracingDemo.prototype.initShaders = function() {

	this.shaderProgram = gl.createProgram();

	gl.attachShader(this.shaderProgram, getShader(gl, "RaytracingDemoVS"));
	gl.attachShader(this.shaderProgram, getShader(gl, "RaytracingDemoFS"));
	gl.linkProgram(this.shaderProgram);

	if (!gl.getProgramParameter(this.shaderProgram, gl.LINK_STATUS)) {
		alert("Could not initialise shaders");
	}

	gl.useProgram(this.shaderProgram);

	this.shaderProgram.vertexPositionAttribute = gl.getAttribLocation(this.shaderProgram, "position");
	gl.enableVertexAttribArray(this.shaderProgram.vertexPositionAttribute);

	this.shaderProgram.projectionMatrixUniform = gl.getUniformLocation(this.shaderProgram, "projectionMatrix");
	this.shaderProgram.modelviewMatrixUniform = gl.getUniformLocation(this.shaderProgram, "modelViewMatrix");
}

RaytracingDemo.prototype.initBuffers = function() {
	this.triangleVertexPositionBuffer = gl.createBuffer();
	gl.bindBuffer(gl.ARRAY_BUFFER, this.triangleVertexPositionBuffer);
	
	var vertices = [
		 -1,  -1,  0,
		 -1,  1,  0,
		 1,  1,  0,

		 -1,  -1,  0,
		 1,  -1,  0,
		 1,  1,  0,
	 ];
	gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(vertices), gl.STATIC_DRAW);
	this.triangleVertexPositionBuffer.itemSize = 3;
	this.triangleVertexPositionBuffer.numItems = 3 * 2;
}

function getTime() {  
	var d = new Date();
	return d.getMinutes() * 60.0 + d.getSeconds() + d.getMilliseconds() / 1000.0;
}

RaytracingDemo.prototype.drawScene = function() {
			
	var perspectiveMatrix = new J3DIMatrix4();	
	perspectiveMatrix.setUniform(gl, this.shaderProgram.projectionMatrixUniform, false);

	var modelViewMatrix = new J3DIMatrix4();	
	modelViewMatrix.setUniform(gl, this.shaderProgram.modelviewMatrixUniform, false);

	gl.uniform1f(gl.getUniformLocation(this.shaderProgram, "time"), getTime());
	
	gl.bindBuffer(gl.ARRAY_BUFFER, this.triangleVertexPositionBuffer);
	gl.vertexAttribPointer(this.shaderProgram.vertexPositionAttribute, this.triangleVertexPositionBuffer.itemSize, gl.FLOAT, false, 0, 0);
	
	gl.uniform2iv(gl.getUniformLocation(this.shaderProgram, "viewport"), [getRenderTargetWidth(), getRenderTargetHeight()]);

	gl.drawArrays(gl.TRIANGLES, 0, this.triangleVertexPositionBuffer.numItems);
}

RaytracingDemo.prototype.run = function() {
	this.initShaders();
	this.initBuffers();

	gl.viewport(0, 0, gl.viewportWidth, gl.viewportHeight);
	gl.clear(gl.COLOR_BUFFER_BIT);

	this.drawScene();
};

function init() {	
	

	env = new RaytracingDemo();	
	env.run();

    return env;
}

function compute(canvas)
{
    env.initShaders();
    env.initBuffers();

    gl.viewport(0, 0, gl.viewportWidth, gl.viewportHeight);
    gl.clear(gl.COLOR_BUFFER_BIT);

    env.drawScene();
}
